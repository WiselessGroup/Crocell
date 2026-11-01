package daemon

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"log"
	"net/http"
	"time"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	pb "git.wiseless.net/fureunoir/crocell/core/api/crocellv1"
	"git.wiseless.net/fureunoir/crocell/core/engine"
	"git.wiseless.net/fureunoir/crocell/core/geo"
)

// ---------- Processes ----------

func (s *Service) ListProcesses(context.Context, *pb.ListProcessesRequest) (*pb.ListProcessesResponse, error) {
	list, err := s.programs()
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}
	resp := &pb.ListProcessesResponse{}
	for _, p := range list {
		resp.Processes = append(resp.Processes, &pb.Process{Name: p.Name, Path: p.Path, Label: p.Label})
	}
	return resp, nil
}

// ---------- Geo databases ----------

func (s *Service) GetGeoInfo(context.Context, *pb.GetGeoInfoRequest) (*pb.GeoInfo, error) {
	return s.geoInfo(), nil
}

// UpdateGeo fetches both files now. When connected with geo rules, the
// fresh sets apply right away by reconnecting.
func (s *Service) UpdateGeo(ctx context.Context, _ *pb.UpdateGeoRequest) (*pb.GeoInfo, error) {
	if err := s.updateGeo(ctx); err != nil {
		return s.geoInfo(), nil // the error is in GeoInfo.error, for the UI to show
	}

	s.mu.Lock()
	conn := s.conn
	usesGeo := false
	if rules, err := engineRules(s.st.Settings.Rules); err == nil {
		ip, site := engine.UsesGeo(rules)
		usesGeo = ip || site
	}
	s.mu.Unlock()

	if usesGeo && conn.state == pb.ConnectionState_CONNECTION_STATE_CONNECTED {
		s.reconnectSoon()
	}
	return s.geoInfo(), nil
}

func (s *Service) geoInfo() *pb.GeoInfo {
	info := s.geo.Info()
	out := &pb.GeoInfo{GeoipCategories: info.GeoIP, GeositeCategories: info.GeoSite}
	if !info.GeoIPUpdated.IsZero() {
		out.GeoipUpdated = timestamppb.New(info.GeoIPUpdated)
	}
	if !info.GeoSiteUpdated.IsZero() {
		out.GeositeUpdated = timestamppb.New(info.GeoSiteUpdated)
	}
	s.mu.Lock()
	out.Updating, out.Error = s.geoBusy, s.geoError
	s.mu.Unlock()
	return out
}

func (s *Service) updateGeo(ctx context.Context) error {
	s.geoMu.Lock()
	defer s.geoMu.Unlock()

	s.mu.Lock()
	src := s.st.Settings.Geo
	s.geoBusy = true
	s.mu.Unlock()

	ctx, cancel := context.WithTimeout(ctx, 3*time.Minute)
	defer cancel()
	err := s.geo.Update(ctx, src.GeoIPSource, src.GeoSiteSource)
	if err == nil {
		engine.ReloadGeo()
	}

	s.mu.Lock()
	s.geoBusy = false
	s.geoError = ""
	if err != nil {
		s.geoError = err.Error()
	}
	s.mu.Unlock()
	return err
}

// tryGeoSources downloads and checks the databases whose source changed,
// without installing them. The error is a sentence for the person.
func (s *Service) tryGeoSources(ctx context.Context, old, next geoSettings) ([]geo.Download, error) {
	var out []geo.Download
	for _, f := range []struct {
		file, label, old, next string
	}{
		{geo.GeoIPFile, "geoip.dat", old.GeoIPSource, next.GeoIPSource},
		{geo.GeoSiteFile, "geosite.dat", old.GeoSiteSource, next.GeoSiteSource},
	} {
		if f.next == f.old {
			continue
		}
		s.geoMu.Lock()
		fctx, cancel := context.WithTimeout(ctx, 3*time.Minute)
		d, err := s.geo.Fetch(fctx, f.file, f.next)
		cancel()
		s.geoMu.Unlock()
		if err != nil {
			return nil, explainGeo(f.label, f.next, err)
		}
		out = append(out, d)
	}
	return out, nil
}

func (s *Service) installGeo(ds []geo.Download) error {
	s.geoMu.Lock()
	defer s.geoMu.Unlock()
	if err := s.geo.Install(ds...); err != nil {
		return err
	}
	engine.ReloadGeo()
	s.mu.Lock()
	s.geoError = ""
	s.mu.Unlock()
	return nil
}

// explainGeo says what is wrong with a geo source in the app's language.
func explainGeo(label, src string, err error) error {
	if src == "" {
		src = "источник по умолчанию"
	}
	var he *geo.HTTPError
	switch {
	case errors.As(err, &he) && he.Status == http.StatusNotFound:
		return fmt.Errorf("%s: по ссылке ничего нет (404). Проверьте адрес: %s", label, src)
	case errors.As(err, &he):
		return fmt.Errorf("%s: сервер ответил ошибкой %d на %s", label, he.Status, src)
	case errors.Is(err, geo.ErrSwapped):
		other := map[string]string{"geoip.dat": "geosite.dat", "geosite.dat": "geoip.dat"}[label]
		return fmt.Errorf("%s: по этой ссылке лежит %s. Похоже, ссылки перепутаны местами.", label, other)
	case errors.Is(err, geo.ErrNotDatabase):
		return fmt.Errorf("%s: по ссылке не база, а что-то другое, скорее всего веб-страница. Нужна прямая ссылка на сам файл .dat.", label)
	case errors.Is(err, fs.ErrNotExist):
		return fmt.Errorf("%s: файла %s нет", label, src)
	case errors.Is(err, fs.ErrPermission):
		return fmt.Errorf("%s: службе не хватает прав прочитать %s", label, src)
	case errors.Is(err, context.DeadlineExceeded):
		return fmt.Errorf("%s: не скачался за 3 минуты с %s", label, src)
	default:
		return fmt.Errorf("%s: не скачался с %s (%v)", label, src, err)
	}
}

// ensureGeo fetches the geo files before a connect that needs them.
func (s *Service) ensureGeo(ctx context.Context, rules []engine.Rule) error {
	needIP, needSite := engine.UsesGeo(rules)
	missingIP, missingSite := s.geo.Missing()
	if !(needIP && missingIP) && !(needSite && missingSite) {
		return nil
	}
	if err := s.updateGeo(ctx); err != nil {
		return fmt.Errorf("rules use geosite/geoip, but the databases could not be downloaded: %w", err)
	}
	return nil
}

// ---------- Background work ----------

// Run does what nobody asks for over the API: connecting on start when
// the person wants that, and keeping the geo files fresh. It returns when
// ctx ends. crocelld calls it; tests do not.
func (s *Service) Run(ctx context.Context) {
	s.mu.Lock()
	connect := s.st.Settings.ConnectOnStart && s.st.Last.SubscriptionID != ""
	s.mu.Unlock()
	if connect {
		if _, err := s.Connect(ctx, &pb.ConnectRequest{}); err != nil {
			log.Printf("crocelld: connect on start: %v", err)
		}
	}

	check := time.NewTicker(time.Hour)
	defer check.Stop()
	for {
		s.refreshGeoIfStale(ctx)
		select {
		case <-ctx.Done():
			return
		case <-check.C:
		}
	}
}

// refreshGeoIfStale updates the files once they are older than the update
// interval, but only if some rule uses them: no traffic for nothing.
func (s *Service) refreshGeoIfStale(ctx context.Context) {
	s.mu.Lock()
	hours := s.st.Settings.Geo.UpdateHours
	rules, err := engineRules(s.st.Settings.Rules)
	s.mu.Unlock()
	if err != nil {
		return
	}
	if ip, site := engine.UsesGeo(rules); !ip && !site {
		return
	}
	if hours <= 0 {
		hours = 24
	}
	info := s.geo.Info()
	oldest := info.GeoIPUpdated
	if info.GeoSiteUpdated.Before(oldest) {
		oldest = info.GeoSiteUpdated
	}
	if !oldest.IsZero() && time.Since(oldest) < time.Duration(hours)*time.Hour {
		return
	}
	if _, err := s.UpdateGeo(ctx, &pb.UpdateGeoRequest{}); err != nil && !errors.Is(err, context.Canceled) {
		log.Printf("crocelld: geo update: %v", err)
	}
}
