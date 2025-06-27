;; Contingency Planning Contract
;; Manages supply chain contingency plans and emergency response procedures

;; Constants
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_PLAN_NOT_FOUND (err u301))
(define-constant ERR_INVALID_STATUS (err u302))
(define-constant ERR_PLAN_ALREADY_ACTIVE (err u303))

;; Data Variables
(define-data-var next-plan-id uint u1)

;; Data Maps
(define-map contingency-plans
  { plan-id: uint }
  {
    creator: principal,
    plan-name: (string-ascii 100),
    scenario-type: (string-ascii 50),
    response-procedures: (string-ascii 1000),
    activation-triggers: (string-ascii 500),
    responsible-parties: (string-ascii 200),
    status: (string-ascii 20),
    creation-date: uint,
    last-activation: uint,
    last-updated: uint
  }
)

(define-map plan-activations
  { plan-id: uint, activation-id: uint }
  {
    activated-by: principal,
    activation-date: uint,
    deactivation-date: uint,
    activation-reason: (string-ascii 200),
    status: (string-ascii 20)
  }
)

(define-map creator-plans
  { creator: principal, plan-id: uint }
  { active: bool }
)

(define-data-var next-activation-id uint u1)

;; Public Functions

;; Create a new contingency plan
(define-public (create-contingency-plan
  (plan-name (string-ascii 100))
  (scenario-type (string-ascii 50))
  (response-procedures (string-ascii 1000))
  (activation-triggers (string-ascii 500))
  (responsible-parties (string-ascii 200))
)
  (let
    (
      (plan-id (var-get next-plan-id))
      (caller tx-sender)
    )
    (map-set contingency-plans
      { plan-id: plan-id }
      {
        creator: caller,
        plan-name: plan-name,
        scenario-type: scenario-type,
        response-procedures: response-procedures,
        activation-triggers: activation-triggers,
        responsible-parties: responsible-parties,
        status: "draft",
        creation-date: block-height,
        last-activation: u0,
        last-updated: block-height
      }
    )

    (map-set creator-plans
      { creator: caller, plan-id: plan-id }
      { active: true }
    )

    (var-set next-plan-id (+ plan-id u1))
    (ok plan-id)
  )
)

;; Activate a contingency plan
(define-public (activate-plan (plan-id uint) (activation-reason (string-ascii 200)))
  (match (map-get? contingency-plans { plan-id: plan-id })
    plan-data
    (let
      (
        (activation-id (var-get next-activation-id))
        (caller tx-sender)
      )
      (asserts! (not (is-eq (get status plan-data) "active")) ERR_PLAN_ALREADY_ACTIVE)

      (map-set contingency-plans
        { plan-id: plan-id }
        (merge plan-data {
          status: "active",
          last-activation: block-height,
          last-updated: block-height
        })
      )

      (map-set plan-activations
        { plan-id: plan-id, activation-id: activation-id }
        {
          activated-by: caller,
          activation-date: block-height,
          deactivation-date: u0,
          activation-reason: activation-reason,
          status: "active"
        }
      )

      (var-set next-activation-id (+ activation-id u1))
      (ok activation-id)
    )
    ERR_PLAN_NOT_FOUND
  )
)

;; Deactivate a contingency plan
(define-public (deactivate-plan (plan-id uint) (activation-id uint))
  (match (map-get? contingency-plans { plan-id: plan-id })
    plan-data
    (match (map-get? plan-activations { plan-id: plan-id, activation-id: activation-id })
      activation-data
      (begin
        (map-set contingency-plans
          { plan-id: plan-id }
          (merge plan-data {
            status: "inactive",
            last-updated: block-height
          })
        )

        (map-set plan-activations
          { plan-id: plan-id, activation-id: activation-id }
          (merge activation-data {
            deactivation-date: block-height,
            status: "completed"
          })
        )
        (ok true)
      )
      ERR_PLAN_NOT_FOUND
    )
    ERR_PLAN_NOT_FOUND
  )
)

;; Update contingency plan
(define-public (update-plan
  (plan-id uint)
  (response-procedures (string-ascii 1000))
  (activation-triggers (string-ascii 500))
  (responsible-parties (string-ascii 200))
)
  (match (map-get? contingency-plans { plan-id: plan-id })
    plan-data
    (begin
      (asserts! (is-eq tx-sender (get creator plan-data)) ERR_UNAUTHORIZED)

      (map-set contingency-plans
        { plan-id: plan-id }
        (merge plan-data {
          response-procedures: response-procedures,
          activation-triggers: activation-triggers,
          responsible-parties: responsible-parties,
          last-updated: block-height
        })
      )
      (ok true)
    )
    ERR_PLAN_NOT_FOUND
  )
)

;; Update plan status
(define-public (update-plan-status (plan-id uint) (new-status (string-ascii 20)))
  (match (map-get? contingency-plans { plan-id: plan-id })
    plan-data
    (begin
      (asserts! (is-eq tx-sender (get creator plan-data)) ERR_UNAUTHORIZED)
      (asserts! (or (is-eq new-status "draft") (is-eq new-status "approved") (is-eq new-status "inactive") (is-eq new-status "archived")) ERR_INVALID_STATUS)

      (map-set contingency-plans
        { plan-id: plan-id }
        (merge plan-data {
          status: new-status,
          last-updated: block-height
        })
      )
      (ok true)
    )
    ERR_PLAN_NOT_FOUND
  )
)

;; Read-only Functions

;; Get contingency plan by ID
(define-read-only (get-contingency-plan (plan-id uint))
  (map-get? contingency-plans { plan-id: plan-id })
)

;; Get plan activation details
(define-read-only (get-plan-activation (plan-id uint) (activation-id uint))
  (map-get? plan-activations { plan-id: plan-id, activation-id: activation-id })
)

;; Check if plan belongs to creator
(define-read-only (is-plan-creator (creator principal) (plan-id uint))
  (default-to false (get active (map-get? creator-plans { creator: creator, plan-id: plan-id })))
)

;; Get total plans count
(define-read-only (get-total-plans)
  (- (var-get next-plan-id) u1)
)

;; Check if plan is currently active
(define-read-only (is-plan-active (plan-id uint))
  (match (map-get? contingency-plans { plan-id: plan-id })
    plan-data
    (is-eq (get status plan-data) "active")
    false
  )
)
