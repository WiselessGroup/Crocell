package daemon

import (
	"context"
	"errors"
	"fmt"
	"log"
	"time"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	pb "git.wiseless.net/fureunoir/crocell/core/api/crocellv1"
	"git.wiseless.net/fureunoir/crocell/core/engine"
	"git.wiseless.net/fureunoir/crocell/core/procs"
)

// ---------- Processes ----------

func (s *Service) ListProcesses(context.Context, *pb.ListProcessesRequest) (*pb.ListProcessesResponse, error) {
	list, err := procs.List()
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}
	resp := &pb.ListProcessesResponse{}
	for _, p := range list {
		resp.Processes = append(resp.Processes, &pb.Process{Name: p.Name, Path: p.Path})
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
		if _, err := s.Connect(ctx, &pb.ConnectRequest{SubscriptionId: conn.subID, NodeId: conn.nodeID}); err != nil {
			return nil, err
		}
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
