#lang racket
(require racket/trace)
(require racket/gui/base)
(require racket/draw)

; Métodos pegar elementos da lista de email
; get-email
(define (sender l)
  (string-downcase (car l)))

; get-id
(define (get-id l)
  (cadddr l))

; get-subject
(define (subject l flag)
  (if flag
      (string-downcase (cadr l))
      (cadr l)))

; get-message
(define (message l flag)
  (if flag
      (string-downcase (caddr l))
      (caddr l)))

; get-server
(define (server l)
  (cadr (string-split (sender l) "@")))

; Autenticador de Email (Blacklist de email e servidor)
(define (auth-email email blackl)
  (cond
    [(null? blackl) #t]
    [(equal? email (car blackl)) #f]
    [else (auth-email email (cdr blackl))]))

; Procura se elemento em lista
(define (in-list word list)
  (cond
    [(null? list) #f]
    [(equal? word (car list)) #t]
    [else (in-list word (cdr list))]))

; Conta numero de palavras em subject ou message que estão na blacklist de palavras)
(define (count-blacklisted words blackl)
  (foldl (λ (word acc) (if (in-list word blackl)
                           (+ 1 acc)
                           (+ 0 acc))) 0 words))

; Autentica subject e message usando um parametro e número de palavras
(define (auth-text text blackl param)
  (if (>= (count-blacklisted (string-split text) blackl) param)
      #f
      #t))

; Limpa a caixa de email inicial, usando filter com os autenticadores anteriores
(define (clean-inbox db tolerancia)
  (let* ([f-filter-server (λ (email) (auth-email (server email) black-list-server))]
         [inbox (filter f-filter-server db)]
         [f-filter-email (λ (email) (auth-email (sender email) black-list-emails))]
         [inbox (filter f-filter-email inbox)]
         [f-filter-sub (λ (email) (auth-text (subject email #t) black-list-words 1))]
         [inbox (filter f-filter-sub inbox)]
         [f-filter-msg (λ (email) (auth-text (message email #t) black-list-words (/ (length (string-split (message email #f))) tolerancia)))]
         [inbox (filter f-filter-msg inbox)])
    inbox))

; Gera a caixa de spam, usando a caixa clean-inbox
(define (spam-inbox db inbox)
  (filter (λ (x) (not (in-list x inbox))) db))

(define test-db
  (car (file->list "test-db.txt")))
 
(define black-list-emails
  (car (file->list "black-list-emails.txt")))

(define black-list-server
  (car (file->list "black-list-server.txt")))

(define black-list-words
  (car (file->list "black-list-words.txt")))

; Atuliza os bancos de dados (em .txt)
(define (update-db s path)
  (print s)
  (cond
    [(= path 0) (write-to-file (string-split s "\n") "black-list-emails.txt" #:exists 'replace) (set! black-list-emails (car (file->list "black-list-emails.txt")))]
    [(= path 1) (write-to-file (string-split s "\n") "black-list-words.txt" #:exists 'replace) (set! black-list-words (car (file->list "black-list-words.txt")))]
    [(= path 2) (write-to-file (string-split s "\n") "black-list-server.txt" #:exists 'replace) (set! black-list-server (car (file->list "black-list-server.txt")))]
    [(= path 3) (write-to-file (string-split s "\n") "test-db.txt" #:exists 'replace) (set! test-db (car (file->list "test.db")))]))

; Definição de fontes para display de email
(define font-subject
  (make-object font% 20 'decorative 'italic 'normal))

(define font-message
  (make-object font% 15 'decorative 'normal 'normal))

; Tela principal
(define tela
  (new frame%
       [label "Caixa de Entrada"]
       [width 500]
       [height 700]
       [alignment '(center top)]
       [border 10]
       [spacing 10]))
  
; Barra de Menu
(define menu-bar
  (new menu-bar%
       [parent tela]))

; Item Editar no menu
(define menu-item
  (new menu%
       [label "Editar"]
       [parent menu-bar]))

; Abre a janela de editor com texto dos arquivos
(define (open-editor-window e db tag id)
  (let ([data (string-join db "\n")])
    (define screen-editor
         (new dialog%
              [label tag]
              [width 200]
              [height 400]))
    (define text-editor
         (new text-field%
           [label #f]
           [parent screen-editor]
           [style '(multiple)]))
    (new button%
         [parent screen-editor]
         [label "Salvar"]
         [callback (λ (a e) (update-db (send text-editor get-value) id)
                     (send screen-editor show #f)
                     (set! cleanbox (clean-inbox test-db tolerancia))
                     (set! spambox (spam-inbox test-db cleanbox))
                     (send filtered set (map (λ (email) (sender email)) cleanbox) (map (λ (email) (subject email #f)) cleanbox))
                     (send un-filtered set (map (λ (email) (sender email)) spambox) (map (λ (email) (subject email #f)) spambox))
                     (set-id filtered cleanbox 0)
                     (set-id un-filtered spambox 0))])
    (new button%
         [parent screen-editor]
         [label "Cancelar"]
         [callback (λ (a e) (send screen-editor show #f))])
    (send text-editor set-value data)
    (send screen-editor show #t)))

; Abre a janela de definição da tolerancia do filtro (inicia com 10)
(define (open-tolerancia-window x)
  (define dialog
    (new dialog%
         [label "Tolerancia"]
         [width 100]
         [height 50]))
  (define message
    (new message%
         [label (~v x)]
         [parent dialog]))
  (new button%
       [label "+"]
       [parent dialog]
       [callback (λ (a e) (set! tolerancia (add1 tolerancia)) (send message set-label (~v tolerancia)))])
  (new button%
       [label "-"]
       [parent dialog]
       [callback (λ (a e) (set! tolerancia (sub1 tolerancia)) (send message set-label (~v tolerancia)))])
  (new button%
       [label "Salvar"]
       [parent dialog]
       [callback (λ (a e) (set! cleanbox (clean-inbox test-db tolerancia))
                   (set! spambox (spam-inbox test-db cleanbox))
                   (send filtered set (map (λ (email) (sender email)) cleanbox) (map (λ (email) (subject email #f)) cleanbox))
                   (send un-filtered set (map (λ (email) (sender email)) spambox) (map (λ (email) (subject email #f)) spambox))
                   (set-id filtered cleanbox 0)
                   (set-id un-filtered spambox 0)
                   (send dialog show #f))])
  (send dialog show #t))
                               
; Itens do Menu Editar
(define editar-emails
  (new menu-item%
       [label "Emails"]
       [parent menu-item]
       [callback (λ (a e) (open-editor-window e black-list-emails "Lista de Emails" 0))]
       [help-string "Editar lista de emails bloqueados pelo filtro de spam."]))

(define editar-servidores
  (new menu-item%
       [label "Servidores"]
       [parent menu-item]
       [callback (λ (a e) (open-editor-window e black-list-server "Lista de Servidores" 2))]
       [help-string "Editar lista de servidores bloqueados pelo filtro de spam."]))

(define editar-palavras
  (new menu-item%
       [label "Palavras"]
       [parent menu-item]
       [callback (λ (a e) (open-editor-window e black-list-words "Lista de Palavras" 1))]
       [help-string "Editar lista de palavras bloqueadas pelo filtro de spam."]))

(define editar-tolerancia
  (new menu-item%
       [label "Tolerancia"]
       [parent menu-item]
       [callback (λ (a e) (open-tolerancia-window tolerancia))]))

; Define as caixas usando as funções passadas e uma tolerencia de limpeza
(define tolerancia 10)
(define cleanbox (clean-inbox test-db tolerancia))
(define spambox (spam-inbox test-db cleanbox))

; Janela de email após clicar em email nas listas
(define (open-email-window e id db)
  (let ([email (car (filter (λ (email) (equal? id (get-id email))) db))])
    (cond
      [(equal? (send e get-event-type) 'list-box-dclick)
      (define screen-email
         (new dialog%
              [label "E-mail"]
              [width 700]
              [height 500]))
      (new message%
           [label (subject email #f)]
           [parent screen-email]
           [font font-subject])
      (new message%
           [label (message email #f)]
           [parent screen-email])
      (send screen-email show #t)])))

; Limpar click nas caixas
(define (double-click box db e)
  (if (null? (send box get-selections))
      '()
       (open-email-window e (send box get-data (car (send box get-selections))) db)))

; Lista com emails filtrados cleanbox
(define filtered
    (new list-box%
         [label "E-mails   "]
         [choices (map (λ (email) (sender email)) cleanbox)]
         [parent tela]
         [callback (λ (a e) (double-click filtered cleanbox e))]
         [columns '("Email" "Assunto")]
         [style '(multiple column-headers)]))

; Lista com emails filtrados spambox
(define un-filtered
    (new list-box%
         [label "Spam      "]
         [choices (map (λ (email) (sender email)) spambox)]
         [parent tela]
         [callback (λ (a e) (double-click un-filtered spambox e))]
         [columns '("Email" "Assunto")]
         [style '(multiple column-headers)]))

; Alimenta os elementos da primeira coluna das listas (colocando os dados na segunda coluna - Assunto)
(define (fill_subject box db acc)
  (cond
    [(null? db) 0]
    [else (send box set-string acc (subject (car db) #f) 1) (fill_subject box (cdr db) (add1 acc))]))

; Seta dados escondidos com os id's de cada email recebido (ordem de chegada na caixa inicial)
(define (set-id box db acc)
  (cond
    [(null? db) 0]
    [else (send box set-data acc (get-id (car db))) (set-id box (cdr db) (add1 acc))]))

; Display na porra toda
(define main (begin
  (fill_subject filtered cleanbox 0)
  (set-id filtered cleanbox 0)
  (fill_subject un-filtered spambox 0)
  (set-id un-filtered spambox 0)
  (send filtered set-column-width 0 150 100 300)
  (send filtered set-column-width 1 200 100 300)
  (send un-filtered set-column-width 0 150 100 300)
  (send un-filtered set-column-width 1 200 100 300)
  (send tela show #t)))
                
