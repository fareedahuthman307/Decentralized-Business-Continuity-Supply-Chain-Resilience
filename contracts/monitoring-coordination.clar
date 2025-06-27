;; Monitoring Coordination Contract
;; Coordinates real-time resilience monitoring and alert management

;; Constants
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_MONITOR_NOT_FOUND (err u401))
(define-constant ERR_ALERT_NOT_FOUND (err u402))
(define-constant ERR_INVALID_STATUS (err u403))
(define-constant ERR_INVALID_SEVERITY (err u404))

;; Data Variables
(define-data-var next-monitor-id uint u1)
(define-data-var next-alert-id uint u1)

;; Data Maps
(define-map monitoring-systems
  { monitor-id: uint }
  {
    operator: principal,
    system-name: (string-ascii 100),
    monitoring-scope: (string-ascii 200),
    alert-thresholds: (string-ascii 300),
    status: (string-ascii 20),
    last-check: uint,
    creation-date: uint,
    last-updated: uint
  }
)

(define-map monitoring-alerts
  { alert-id: uint }
  {
    monitor-id: uint,
    triggered-by: principal,
    alert-type: (string-ascii 50),
    severity: (string-ascii 20),
    description: (string-ascii 500),
    trigger-time: uint,
    acknowledgment-time: uint,
    resolution-time: uint,
    status: (string-ascii 20),
    assigned-to: principal
  }
)

(define-map operator-monitors
  { operator: principal, monitor-id: uint }
  { active: bool }
)

;; Public Functions

;; Register a new monitoring system
(define-public (register-monitoring-system
  (system-name (string-ascii 100))
  (monitoring-scope (string-ascii 200))
  (alert-thresholds (string-ascii 300))
)
  (let
    (
      (monitor-id (var-get next-monitor-id))
      (caller tx-sender)
    )
    (map-set monitoring-systems
      { monitor-id: monitor-id }
      {
        operator: caller,
        system-name: system-name,
        monitoring-scope: monitoring-scope,
        alert-thresholds: alert-thresholds,
        status: "active",
        last-check: block-height,
        creation-date: block-height,
        last-updated: block-height
      }
    )

    (map-set operator-monitors
      { operator: caller, monitor-id: monitor-id }
      { active: true }
    )

    (var-set next-monitor-id (+ monitor-id u1))
    (ok monitor-id)
  )
)

;; Update monitoring system status
(define-public (update-monitor-status (monitor-id uint) (new-status (string-ascii 20)))
  (match (map-get? monitoring-systems { monitor-id: monitor-id })
    monitor-data
    (begin
      (asserts! (is-eq tx-sender (get operator monitor-data)) ERR_UNAUTHORIZED)
      (asserts! (or (is-eq new-status "active") (is-eq new-status "inactive") (is-eq new-status "maintenance") (is-eq new-status "error")) ERR_INVALID_STATUS)

      (map-set monitoring-systems
        { monitor-id: monitor-id }
        (merge monitor-data {
          status: new-status,
          last-updated: block-height
        })
      )
      (ok true)
    )
    ERR_MONITOR_NOT_FOUND
  )
)

;; Record system check
(define-public (record-system-check (monitor-id uint))
  (match (map-get? monitoring-systems { monitor-id: monitor-id })
    monitor-data
    (begin
      (asserts! (is-eq tx-sender (get operator monitor-data)) ERR_UNAUTHORIZED)

      (map-set monitoring-systems
        { monitor-id: monitor-id }
        (merge monitor-data {
          last-check: block-height,
          last-updated: block-height
        })
      )
      (ok true)
    )
    ERR_MONITOR_NOT_FOUND
  )
)

;; Trigger monitoring alert
(define-public (trigger-alert
  (monitor-id uint)
  (alert-type (string-ascii 50))
  (severity (string-ascii 20))
  (description (string-ascii 500))
  (assigned-to principal)
)
  (let
    (
      (alert-id (var-get next-alert-id))
      (caller tx-sender)
    )
    (asserts! (is-some (map-get? monitoring-systems { monitor-id: monitor-id })) ERR_MONITOR_NOT_FOUND)
    (asserts! (or (is-eq severity "low") (is-eq severity "medium") (is-eq severity "high") (is-eq severity "critical")) ERR_INVALID_SEVERITY)

    (map-set monitoring-alerts
      { alert-id: alert-id }
      {
        monitor-id: monitor-id,
        triggered-by: caller,
        alert-type: alert-type,
        severity: severity,
        description: description,
        trigger-time: block-height,
        acknowledgment-time: u0,
        resolution-time: u0,
        status: "open",
        assigned-to: assigned-to
      }
    )

    (var-set next-alert-id (+ alert-id u1))
    (ok alert-id)
  )
)

;; Acknowledge alert
(define-public (acknowledge-alert (alert-id uint))
  (match (map-get? monitoring-alerts { alert-id: alert-id })
    alert-data
    (begin
      (asserts! (is-eq tx-sender (get assigned-to alert-data)) ERR_UNAUTHORIZED)

      (map-set monitoring-alerts
        { alert-id: alert-id }
        (merge alert-data {
          acknowledgment-time: block-height,
          status: "acknowledged"
        })
      )
      (ok true)
    )
    ERR_ALERT_NOT_FOUND
  )
)

;; Resolve alert
(define-public (resolve-alert (alert-id uint))
  (match (map-get? monitoring-alerts { alert-id: alert-id })
    alert-data
    (begin
      (asserts! (is-eq tx-sender (get assigned-to alert-data)) ERR_UNAUTHORIZED)

      (map-set monitoring-alerts
        { alert-id: alert-id }
        (merge alert-data {
          resolution-time: block-height,
          status: "resolved"
        })
      )
      (ok true)
    )
    ERR_ALERT_NOT_FOUND
  )
)

;; Read-only Functions

;; Get monitoring system by ID
(define-read-only (get-monitoring-system (monitor-id uint))
  (map-get? monitoring-systems { monitor-id: monitor-id })
)

;; Get alert by ID
(define-read-only (get-alert (alert-id uint))
  (map-get? monitoring-alerts { alert-id: alert-id })
)

;; Check if operator owns monitor
(define-read-only (is-monitor-operator (operator principal) (monitor-id uint))
  (default-to false (get active (map-get? operator-monitors { operator: operator, monitor-id: monitor-id })))
)

;; Get total monitors count
(define-read-only (get-total-monitors)
  (- (var-get next-monitor-id) u1)
)

;; Get total alerts count
(define-read-only (get-total-alerts)
  (- (var-get next-alert-id) u1)
)

;; Check if alert is critical
(define-read-only (is-alert-critical (alert-id uint))
  (match (map-get? monitoring-alerts { alert-id: alert-id })
    alert-data
    (is-eq (get severity alert-data) "critical")
    false
  )
)
