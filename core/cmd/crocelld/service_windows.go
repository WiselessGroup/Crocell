package main

import (
	"context"
	"log"

	"golang.org/x/sys/windows/svc"
)

const serviceName = "crocelld"

// runService runs crocelld under the service manager when that is who
// started it. Run by hand, it returns false and crocelld runs in the
// console.
func runService(args []string) (bool, error) {
	isService, err := svc.IsWindowsService()
	if err != nil || !isService {
		return false, nil
	}
	return true, svc.Run(serviceName, &service{args: args})
}

type service struct{ args []string }

func (s *service) Execute(_ []string, req <-chan svc.ChangeRequest, st chan<- svc.Status) (bool, uint32) {
	st <- svc.Status{State: svc.StartPending}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	done := make(chan error, 1)
	go func() { done <- serve(ctx, s.args) }()
	st <- svc.Status{State: svc.Running, Accepts: svc.AcceptStop | svc.AcceptShutdown}

	// A non-zero code makes the service manager apply the restart actions
	// install sets up.
	exitCode := func(err error) (bool, uint32) {
		if err != nil {
			log.Printf("crocelld: %v", err)
			return true, 1
		}
		return false, 0
	}
	for {
		select {
		case c := <-req:
			switch c.Cmd {
			case svc.Interrogate:
				st <- c.CurrentStatus
			case svc.Stop, svc.Shutdown:
				st <- svc.Status{State: svc.StopPending}
				cancel()
				return exitCode(<-done)
			}
		case err := <-done:
			return exitCode(err)
		}
	}
}
