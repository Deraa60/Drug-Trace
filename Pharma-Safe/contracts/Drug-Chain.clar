;; PHARMSECURE: BLOCKCHAIN-BASED PHARMACEUTICAL AUTHENTICATION & SUPPLY CHAIN PLATFORM SMART CONTRACT
;; 
;; DESCRIPTION:
;; PharmSecure is a comprehensive blockchain-based platform designed to combat counterfeit 
;; pharmaceuticals through cryptographic authentication, immutable supply chain tracking, 
;; and real-time verification capabilities. The system provides end-to-end traceability 
;; from manufacturing to patient delivery, ensuring drug authenticity and safety.
;;
;; KEY FEATURES:
;; - Cryptographic drug fingerprinting and authentication
;; - Multi-stakeholder verification ecosystem (manufacturers, distributors, pharmacies, regulators)
;; - Real-time counterfeit detection and alerts
;; - Immutable supply chain custody tracking
;; - Automated compliance monitoring and expiry validation
;; - Comprehensive audit trails for regulatory oversight
;; - Emergency product recall capabilities

;; ERROR CONSTANTS AND SYSTEM CONFIGURATION

(define-constant contract-owner tx-sender)

;; Authentication and Authorization Errors
(define-constant ERR-UNAUTHORIZED-ACCESS (err u1001))
(define-constant ERR-INSUFFICIENT-PRIVILEGES (err u1002))
(define-constant ERR-INVALID-PRINCIPAL (err u1003))

;; Data Validation Errors
(define-constant ERR-INVALID-INPUT-FORMAT (err u2001))
(define-constant ERR-INVALID-STRING-LENGTH (err u2002))
(define-constant ERR-INVALID-HASH-FORMAT (err u2003))
(define-constant ERR-INVALID-TIMESTAMP (err u2004))

;; Resource Management Errors
(define-constant ERR-RESOURCE-NOT-FOUND (err u3001))
(define-constant ERR-DUPLICATE-REGISTRATION (err u3002))
(define-constant ERR-EXPIRED-PRODUCT (err u3003))
(define-constant ERR-INSUFFICIENT-INVENTORY (err u3004))

;; Verification Errors
(define-constant ERR-HASH-VERIFICATION-FAILED (err u4001))
(define-constant ERR-PRODUCT-NOT-VERIFIED (err u4002))

;; GLOBAL STATE VARIABLES

(define-data-var platform-admin principal contract-owner)
(define-data-var next-drug-id uint u1)
(define-data-var next-audit-id uint u1)
(define-data-var next-transfer-id uint u1)

;; STAKEHOLDER MANAGEMENT DATA STRUCTURES

;; Pharmaceutical Manufacturer Registry
(define-map drug-manufacturers
  principal
  {
    company-name: (string-ascii 120),
    facility-location: (string-ascii 200),
    license-active: bool,
    registration-time: uint,
    licensing-authority: principal
  }
)

;; Authorized Verification Entities (pharmacies, distributors, regulators)
(define-map verification-entities
  principal
  {
    entity-type: (string-ascii 50),
    authorization-active: bool,
    registration-time: uint,
    authorized-by: principal
  }
)

;; PHARMACEUTICAL PRODUCT DATA STRUCTURES

;; Master Drug Registry
(define-map pharmaceutical-products
  uint
  {
    drug-id: uint,
    manufacturer: principal,
    brand-name: (string-ascii 150),
    batch-code: (string-ascii 100),
    production-date: uint,
    expiry-date: uint,
    total-units: uint,
    remaining-units: uint,
    authenticity-hash: (buff 32),
    is-verified: bool,
    verification-time: (optional uint),
    verified-by: (optional principal),
    current-location: (string-ascii 200),
    regulatory-approval: (string-ascii 100),
    active-ingredients: (string-ascii 300)
  }
)

;; Batch Code Lookup Index
(define-map batch-lookup
  (string-ascii 100)
  {
    drug-id: uint,
    manufacturer: principal,
    production-facility: (string-ascii 200),
    indexed-at: uint
  }
)

;; Regulatory Approval Lookup
(define-map approval-lookup
  (string-ascii 100)
  {
    drug-id: uint,
    approving-authority: (string-ascii 120),
    approval-date: uint
  }
)

;; AUDIT AND TRACKING DATA STRUCTURES

;; Verification Audit Trail
(define-map verification-logs
  uint
  {
    drug-id: uint,
    verifier: principal,
    verification-time: uint,
    verification-result: bool,
    method-used: (string-ascii 120),
    location: (string-ascii 200),
    notes: (string-ascii 500),
    additional-data: (string-ascii 300)
  }
)

;; Supply Chain Transfer Records
(define-map custody-transfers
  uint
  {
    drug-id: uint,
    from-entity: principal,
    to-entity: principal,
    transfer-time: uint,
    transfer-location: (string-ascii 200),
    authorization-ref: (string-ascii 120),
    units-transferred: uint
  }
)

;; INPUT VALIDATION FUNCTIONS

(define-private (is-valid-principal (user-principal principal))
  (and 
    (not (is-eq user-principal 'SP000000000000000000002Q6VF78))
    (not (is-eq user-principal 'ST000000000000000000002AMW42H))
  )
)

(define-private (is-valid-string (input-str (string-ascii 500)))
  (and 
    (> (len input-str) u0)
    (<= (len input-str) u500)
  )
)

(define-private (is-valid-hash (hash-buffer (buff 32)))
  (is-eq (len hash-buffer) u32)
)

(define-private (validate-company-name (company-name (string-ascii 120)))
  (begin
    (asserts! (> (len company-name) u0) ERR-INVALID-STRING-LENGTH)
    (asserts! (<= (len company-name) u120) ERR-INVALID-STRING-LENGTH)
    (ok company-name)
  )
)

(define-private (validate-location (location (string-ascii 200)))
  (begin
    (asserts! (> (len location) u0) ERR-INVALID-STRING-LENGTH)
    (asserts! (<= (len location) u200) ERR-INVALID-STRING-LENGTH)
    (ok location)
  )
)

(define-private (validate-method-description (method (string-ascii 120)))
  (begin
    (asserts! (> (len method) u0) ERR-INVALID-STRING-LENGTH)
    (asserts! (<= (len method) u120) ERR-INVALID-STRING-LENGTH)
    (ok method)
  )
)

;; MANUFACTURER MANAGEMENT FUNCTIONS

(define-public (register-manufacturer
  (manufacturer-principal principal)
  (company-name (string-ascii 120))
  (facility-location (string-ascii 200))
)
  (let (
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    (validated-name (unwrap! (validate-company-name company-name) ERR-INVALID-INPUT-FORMAT))
    (validated-location (unwrap! (validate-location facility-location) ERR-INVALID-INPUT-FORMAT))
  )
    (asserts! (is-eq tx-sender (var-get platform-admin)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-valid-principal manufacturer-principal) ERR-INVALID-PRINCIPAL)
    (asserts! (is-none (map-get? drug-manufacturers manufacturer-principal)) ERR-DUPLICATE-REGISTRATION)
    
    (ok (map-set drug-manufacturers manufacturer-principal {
      company-name: validated-name,
      facility-location: validated-location,
      license-active: true,
      registration-time: current-time,
      licensing-authority: tx-sender
    }))
  )
)

(define-public (update-manufacturer-status
  (manufacturer-principal principal)
  (new-status bool)
)
  (let (
    (manufacturer-data (unwrap! (map-get? drug-manufacturers manufacturer-principal) ERR-RESOURCE-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (var-get platform-admin)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-valid-principal manufacturer-principal) ERR-INVALID-PRINCIPAL)
    
    (ok (map-set drug-manufacturers manufacturer-principal 
      (merge manufacturer-data { license-active: new-status })
    ))
  )
)

(define-public (register-verification-entity
  (entity-principal principal)
  (entity-type (string-ascii 50))
)
  (let (
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
  )
    (asserts! (is-eq tx-sender (var-get platform-admin)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-valid-principal entity-principal) ERR-INVALID-PRINCIPAL)
    (asserts! (or (is-eq entity-type "pharmacy") 
                  (or (is-eq entity-type "distributor") 
                      (or (is-eq entity-type "regulator")
                          (is-eq entity-type "hospital")))) ERR-INVALID-INPUT-FORMAT)
    
    (ok (map-set verification-entities entity-principal {
      entity-type: entity-type,
      authorization-active: true,
      registration-time: current-time,
      authorized-by: tx-sender
    }))
  )
)

;; PHARMACEUTICAL PRODUCT REGISTRATION

(define-public (register-pharmaceutical-product
  (brand-name (string-ascii 150))
  (batch-code (string-ascii 100))
  (production-date uint)
  (expiry-date uint)
  (total-units uint)
  (authenticity-hash (buff 32))
  (current-location (string-ascii 200))
  (regulatory-approval (string-ascii 100))
  (active-ingredients (string-ascii 300))
)
  (let (
    (drug-id (var-get next-drug-id))
    (manufacturer tx-sender)
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    (manufacturer-record (unwrap! (map-get? drug-manufacturers manufacturer) ERR-UNAUTHORIZED-ACCESS))
    (validated-location (unwrap! (validate-location current-location) ERR-INVALID-INPUT-FORMAT))
  )
    ;; Validation checks
    (asserts! (get license-active manufacturer-record) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-valid-string brand-name) ERR-INVALID-INPUT-FORMAT)
    (asserts! (is-valid-string batch-code) ERR-INVALID-INPUT-FORMAT)
    (asserts! (is-valid-string regulatory-approval) ERR-INVALID-INPUT-FORMAT)
    (asserts! (is-valid-hash authenticity-hash) ERR-INVALID-HASH-FORMAT)
    (asserts! (> expiry-date production-date) ERR-INVALID-TIMESTAMP)
    (asserts! (> total-units u0) ERR-INVALID-INPUT-FORMAT)
    (asserts! (is-none (map-get? batch-lookup batch-code)) ERR-DUPLICATE-REGISTRATION)
    
    ;; Register product in main registry
    (map-set pharmaceutical-products drug-id {
      drug-id: drug-id,
      manufacturer: manufacturer,
      brand-name: brand-name,
      batch-code: batch-code,
      production-date: production-date,
      expiry-date: expiry-date,
      total-units: total-units,
      remaining-units: total-units,
      authenticity-hash: authenticity-hash,
      is-verified: false,
      verification-time: none,
      verified-by: none,
      current-location: validated-location,
      regulatory-approval: regulatory-approval,
      active-ingredients: active-ingredients
    })
    
    ;; Create lookup indices
    (map-set batch-lookup batch-code {
      drug-id: drug-id,
      manufacturer: manufacturer,
      production-facility: validated-location,
      indexed-at: current-time
    })
    
    (map-set approval-lookup regulatory-approval {
      drug-id: drug-id,
      approving-authority: "FDA",
      approval-date: current-time
    })
    
    ;; Update counters
    (var-set next-drug-id (+ drug-id u1))
    
    (ok drug-id)
  )
)

;; AUTHENTICATION AND VERIFICATION SYSTEM

(define-public (verify-pharmaceutical-authenticity
  (drug-id uint)
  (provided-hash (buff 32))
  (verification-location (string-ascii 200))
  (verification-method (string-ascii 120))
)
  (let (
    (product-data (unwrap! (map-get? pharmaceutical-products drug-id) ERR-RESOURCE-NOT-FOUND))
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    (audit-id (var-get next-audit-id))
    (verifier tx-sender)
    (entity-auth (map-get? verification-entities verifier))
    (validated-location (unwrap! (validate-location verification-location) ERR-INVALID-INPUT-FORMAT))
    (validated-method (unwrap! (validate-method-description verification-method) ERR-INVALID-INPUT-FORMAT))
  )
    ;; Validation checks
    (asserts! (is-valid-hash provided-hash) ERR-INVALID-HASH-FORMAT)
    (asserts! (or (is-some entity-auth)
                  (is-eq verifier (var-get platform-admin))) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (> (get expiry-date product-data) current-time) ERR-EXPIRED-PRODUCT)
    
    ;; Perform hash verification
    (let (
      (verification-successful (is-eq (get authenticity-hash product-data) provided-hash))
      (audit-notes (if verification-successful 
        "AUTHENTIC: Hash verification successful - Product confirmed genuine"
        "COUNTERFEIT DETECTED: Hash mismatch - QUARANTINE REQUIRED"))
    )
      ;; Update product if verification successful
      (if verification-successful
        (map-set pharmaceutical-products drug-id 
          (merge product-data {
            is-verified: true,
            verification-time: (some current-time),
            verified-by: (some verifier)
          }))
        false
      )
      
      ;; Create audit log
      (map-set verification-logs audit-id {
        drug-id: drug-id,
        verifier: verifier,
        verification-time: current-time,
        verification-result: verification-successful,
        method-used: validated-method,
        location: validated-location,
        notes: audit-notes,
        additional-data: (concat "BATCH: " (get batch-code product-data))
      })
      
      (var-set next-audit-id (+ audit-id u1))
      
      (ok verification-successful)
    )
  )
)

(define-public (verify-by-batch-code
  (batch-code (string-ascii 100))
  (provided-hash (buff 32))
  (verification-location (string-ascii 200))
)
  (let (
    (batch-data (unwrap! (map-get? batch-lookup batch-code) ERR-RESOURCE-NOT-FOUND))
    (drug-id (get drug-id batch-data))
    (validated-location (unwrap! (validate-location verification-location) ERR-INVALID-INPUT-FORMAT))
  )
    (asserts! (is-valid-hash provided-hash) ERR-INVALID-HASH-FORMAT)
    (verify-pharmaceutical-authenticity 
      drug-id 
      provided-hash 
      validated-location
      "BATCH-CODE-VERIFICATION")
  )
)

;; SUPPLY CHAIN MANAGEMENT

(define-public (transfer-custody
  (drug-id uint)
  (recipient principal)
  (transfer-location (string-ascii 200))
  (authorization-ref (string-ascii 120))
  (units-to-transfer uint)
)
  (let (
    (product-data (unwrap! (map-get? pharmaceutical-products drug-id) ERR-RESOURCE-NOT-FOUND))
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    (transfer-id (var-get next-transfer-id))
    (validated-location (unwrap! (validate-location transfer-location) ERR-INVALID-INPUT-FORMAT))
  )
    ;; Validation checks
    (asserts! (is-valid-principal recipient) ERR-INVALID-PRINCIPAL)
    (asserts! (is-valid-string authorization-ref) ERR-INVALID-INPUT-FORMAT)
    (asserts! (> units-to-transfer u0) ERR-INVALID-INPUT-FORMAT)
    (asserts! (<= units-to-transfer (get remaining-units product-data)) ERR-INSUFFICIENT-INVENTORY)
    
    ;; Verify transfer authorization
    (asserts! (or (is-eq tx-sender (get manufacturer product-data))
                  (is-some (map-get? verification-entities tx-sender))) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Record transfer
    (map-set custody-transfers transfer-id {
      drug-id: drug-id,
      from-entity: tx-sender,
      to-entity: recipient,
      transfer-time: current-time,
      transfer-location: validated-location,
      authorization-ref: authorization-ref,
      units-transferred: units-to-transfer
    })
    
    ;; Update product location and inventory
    (map-set pharmaceutical-products drug-id
      (merge product-data { 
        current-location: validated-location,
        remaining-units: (- (get remaining-units product-data) units-to-transfer)
      }))
    
    (var-set next-transfer-id (+ transfer-id u1))
    
    (ok transfer-id)
  )
)

(define-public (update-inventory-levels
  (drug-id uint)
  (new-quantity uint)
)
  (let (
    (product-data (unwrap! (map-get? pharmaceutical-products drug-id) ERR-RESOURCE-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get manufacturer product-data)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (>= new-quantity u0) ERR-INVALID-INPUT-FORMAT)
    
    (ok (map-set pharmaceutical-products drug-id
      (merge product-data { remaining-units: new-quantity })
    ))
  )
)

;; PLATFORM ADMINISTRATION

(define-public (transfer-admin-rights (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-admin)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-valid-principal new-admin) ERR-INVALID-PRINCIPAL)
    (ok (var-set platform-admin new-admin))
  )
)

;; READ-ONLY QUERY FUNCTIONS

(define-read-only (get-product-info (drug-id uint))
  (map-get? pharmaceutical-products drug-id)
)

(define-read-only (get-product-by-batch (batch-code (string-ascii 100)))
  (match (map-get? batch-lookup batch-code)
    batch-info (map-get? pharmaceutical-products (get drug-id batch-info))
    none
  )
)

(define-read-only (get-product-by-approval (approval-code (string-ascii 100)))
  (match (map-get? approval-lookup approval-code)
    approval-info (map-get? pharmaceutical-products (get drug-id approval-info))
    none
  )
)

(define-read-only (is-manufacturer-authorized (manufacturer principal))
  (match (map-get? drug-manufacturers manufacturer)
    manufacturer-data (get license-active manufacturer-data)
    false
  )
)

(define-read-only (check-product-validity (drug-id uint))
  (match (map-get? pharmaceutical-products drug-id)
    product-data
      (let (
        (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      )
        (and 
          (get is-verified product-data)
          (> (get expiry-date product-data) current-time)
          (> (get remaining-units product-data) u0)
        )
      )
    false
  )
)

(define-read-only (get-verification-log (audit-id uint))
  (map-get? verification-logs audit-id)
)

(define-read-only (get-transfer-record (transfer-id uint))
  (map-get? custody-transfers transfer-id)
)

(define-read-only (get-platform-admin)
  (var-get platform-admin)
)

(define-read-only (get-platform-stats)
  {
    total-products: (- (var-get next-drug-id) u1),
    total-verifications: (- (var-get next-audit-id) u1),
    total-transfers: (- (var-get next-transfer-id) u1)
  }
)

(define-read-only (get-product-hash (drug-id uint))
  (match (map-get? pharmaceutical-products drug-id)
    product-data (some (get authenticity-hash product-data))
    none
  )
)

(define-read-only (product-exists (drug-id uint))
  (is-some (map-get? pharmaceutical-products drug-id))
)

(define-read-only (get-entity-info (entity principal))
  (map-get? verification-entities entity)
)

(define-read-only (get-batch-traceability (batch-code (string-ascii 100)))
  (match (map-get? batch-lookup batch-code)
    batch-info 
      (let (
        (drug-id (get drug-id batch-info))
        (product-data (map-get? pharmaceutical-products drug-id))
      )
        (some {
          batch-info: batch-info,
          product-data: product-data,
          manufacturer-info: (map-get? drug-manufacturers (get manufacturer batch-info))
        })
      )
    none
  )
)

(define-read-only (get-manufacturer-products (manufacturer principal))
  (map-get? drug-manufacturers manufacturer)
)

(define-read-only (check-expiry-status (drug-id uint))
  (match (map-get? pharmaceutical-products drug-id)
    product-data
      (let (
        (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
        (expiry-time (get expiry-date product-data))
      )
        (some {
          product-id: drug-id,
          current-time: current-time,
          expiry-time: expiry-time,
          is-expired: (>= current-time expiry-time),
          days-remaining: (if (> expiry-time current-time) 
                           (/ (- expiry-time current-time) u86400)
                           u0)
        })
      )
    none
  )
)

(define-read-only (get-verification-history (drug-id uint))
  (match (map-get? pharmaceutical-products drug-id)
    product-data
      (some {
        product-id: drug-id,
        is-verified: (get is-verified product-data),
        verification-time: (get verification-time product-data),
        verified-by: (get verified-by product-data)
      })
    none
  )
)

(define-read-only (get-global-inventory-status)
  (let (
    (total-products (- (var-get next-drug-id) u1))
  )
    {
      total-registered-products: total-products,
      total-verification-attempts: (- (var-get next-audit-id) u1),
      total-custody-transfers: (- (var-get next-transfer-id) u1),
      platform-administrator: (var-get platform-admin)
    }
  )
)

(define-read-only (check-operation-authorization (entity principal) (operation (string-ascii 50)))
  (let (
    (entity-record (map-get? verification-entities entity))
    (manufacturer-record (map-get? drug-manufacturers entity))
    (is-admin (is-eq entity (var-get platform-admin)))
  )
    {
      is-verification-entity: (is-some entity-record),
      is-manufacturer: (is-some manufacturer-record),
      is-admin: is-admin,
      can-operate: (or is-admin 
                      (and (is-some entity-record) 
                           (get authorization-active (unwrap-panic entity-record)))
                      (and (is-some manufacturer-record) 
                           (get license-active (unwrap-panic manufacturer-record))))
    }
  )
)