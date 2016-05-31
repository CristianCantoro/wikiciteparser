-- Modulo per la gestione delle citazioni, originariamente importato dalla
-- revisione 555909894 del 20/5/2013 da [[:en:Module:Citation/CS1]]

--[[ ===============================================================================
Variabile in cui vengono memorizzate le condizioni di errore registrate durante l'esecusione
delle funzioni del modulo.
    ===============================================================================]]
function (sample, export_ustring_match, export_ustring_len, export_uri_encode, export_text_split, export_nowiki)
local z = {
    error_categories = {}; -- lista delle categorie di errore
    error_ids = {}; -- lista dei codici di errore
    message_tail = {}; -- messagi di errore da visualizzare in coda alla citazione
}

--[[ ===============================================================================
Caricamente delle tabelle di configurazione del modulo.
    ===============================================================================]]
local cfg = mw.loadData( 'Modulo:Citazione/Configurazione' );

--[[ ===============================================================================
Lista di tutti i parametri riconosciuti.
    ===============================================================================]]
local whitelist = mw.loadData( 'Modulo:Citazione/Whitelist' );

--[[ ===============================================================================
Ritorna true se una variabile è settata (diversa da nil e da stringa vuota)
    ===============================================================================]]
local function is_set( var )
    return not (var == nil or var == '');
end

--[[ ===============================================================================
Ritorna la prima variabile settata di quelle passate alla funzione
    ===============================================================================]]
local function first_set(...)
    local list = {...};
    for _, var in pairs(list) do
        if is_set( var ) then
            return var;
        end
    end
end

--[[ ===============================================================================
Ritorna la posizione di needle nella lista haystack, altrimenti ritorna false
    ===============================================================================]]
local function in_array( needle, haystack )
    if needle == nil then return false; end
    for n,v in ipairs( haystack ) do
        if v == needle then return n; end
    end
    return false;
end

--[[ ===============================================================================
Popola gli argomenti numerati nella stringa msg usando la tabella di argomenti args
    ===============================================================================]]
local function substitute( msg, args )
    return args and mw.message.newRawMessage( msg, args ):plain() or msg;
end

--[[ ===============================================================================
Rende la stringa sicura per il markup corsivo '' ... ''
Nota: non si può usare <i> per il corisvo poichè il comportamento atteso se lo si
specifica per i titoli è di renderli non corsivi. Inoltre <i> e '' interagiscono
male con la funzione HTML tidy di Mediawiki
    ===============================================================================]]
local function safe_for_italics( str )
    if not is_set(str) then
        return str;
    else
        if str:sub(1,1) == "'" then str = "<span />" .. str; end
        if str:sub(-1,-1) == "'" then str = str .. "<span />"; end

        -- Remove newlines as they break italics.
        return str:gsub( '\n', ' ' );
    end
end

--[[ ===============================================================================
Restituisce un messaggio dalla tabella cfg.messages in cui viene inserita una stringa
- key: codice del messaggio da visualizzare in cfg.messages
- str: una stringa da inserire nel messaggio, se non è definita o uguale a stringa
    vuota la funzione ritorna una stringa vuota
    ===============================================================================]]
local function wrap( key, str )
    if not is_set( str ) then
        return "";
    elseif in_array( key, { 'italic-title', 'trans-italic-title' } ) then
        str = safe_for_italics( str );
    end
    return substitute( cfg.messages[key], {str} );
end

--[[ ===============================================================================
Inserisce un messaggio di debug da visualizzare in coda alla citazione
    ===============================================================================]]
local function debug_msg(msg)
    table.insert( z.message_tail, { set_error( 'debug_txt', {msg}, true ) } );
end

--[[ ===============================================================================
A scopo di debug, aggiunge la stringa 'name=<value>' in coda alla citazione
    ===============================================================================]]
local function debug_value(name, value)
    if not value then value='nil' end
    debug_msg(name .. '="'.. value .. '"')
end

--[[ ===============================================================================
Formatta un commento per identificare gli errori, aggiungendo la classe css per
renderlo visibile o meno
    ===============================================================================]]
local function error_comment( content, hidden )
    return wrap( hidden and 'hidden-error' or 'visible-error', content );
end

--[[ ===============================================================================
Imposta un condizione di errore e ritorna un messaggio appropriato. L'inserimento
del messaggio nell'output è di responsabilità della funzione chiamante
-- -- error_id: codice dell'errore (una chiave valida per cfg.error_conditions)
-- -- arguments: una lista di argomenti opzionali per la formattazione del messaggio
-- -- raw: ritorna una coppia: {messaggio di errore, visibilità} invece del messaggio
--         di errore formattato
-- -- prefix: stringa da aggiungere in testa al messaggio
-- -- suffix: stringa da aggiungere in coda al messaggio
    ===============================================================================]]
local function set_error( error_id, arguments, raw, prefix, suffix )
    local error_state = cfg.error_conditions[ error_id ];

    prefix = prefix or "";
    suffix = suffix or "";

    if error_state == nil then
        error( cfg.messages['undefined_error'] );
    elseif is_set( error_state.category ) then
        table.insert( z.error_categories, error_state.category );
    end

    local message = substitute( error_state.message, arguments );

    message = mw.ustring.format('%s ([[%s#%s|%s]])',
                message, cfg.messages['help page link'], error_state.anchor,
                cfg.messages['help page label']
            )

    z.error_ids[ error_id ] = true;
    if in_array( error_id, { 'bare_url_missing_title', 'trans_missing_title' } )
            and z.error_ids['citation_missing_title'] then
        return '', false;
    end

    message = table.concat({ prefix, message, suffix });
    if raw == true then return message, error_state.hidden end
    return error_comment( message, error_state.hidden );
end

--[[ ===============================================================================
Cerca il primo parametro settato da una lista di parametri e genera un errore se
più di un parametro è settato.
Ritorna la coppia (value, selected) dove value è il valore del parametro trovato e
selected il nome del parametro trovato
    ===============================================================================]]
local function select_one( args, possible, error_condition, index )
    local value = nil;
    local selected = '';
    local error_list = {};

    if index ~= nil then index = tostring(index); end

    -- Handle special case of "#" replaced by empty string
    if index == '1' then
        for _, v in ipairs( possible ) do
            v = v:gsub( "#", "" );
            if is_set(args[v]) then
                if value ~= nil and selected ~= v then
                    table.insert( error_list, wrap( 'parameter', v ) );
                else
                    value = args[v];
                    selected = v;
                end
            end
        end
    end

    for _, v in ipairs( possible ) do
        if index ~= nil then
            v = v:gsub( "#", index );
        end
        if is_set(args[v]) then
            if value ~= nil and selected ~= v then
                table.insert( error_list, wrap( 'parameter', v ));
            else
                value = args[v];
                selected = v;
            end
        end
    end

    if #error_list > 0 then
        -- genera il messaggio di errore concatenando i parametri duplicati
        local error_str = "";
        if #error_list == 1 then
            error_str = error_list[1] .. cfg.messages['parameter-pair-separator'];
        else
            error_str = table.concat(error_list, cfg.messages['parameter-separator']) .. cfg.messages['parameter-final-separator'];
        end
        error_str = error_str .. wrap( 'parameter', selected );
        table.insert( z.message_tail, { set_error( error_condition, {error_str}, true ) } );
    end
    return value, selected;
end

--[[ ===============================================================================
Funzione di supporto per la mappatura degli argomenti del file di configurazione,
così che nomi multipli possono essere assegnati ad una singola variabile interna
    ===============================================================================]]
local function argument_wrapper( args )
    local origin = {};

    return setmetatable({
        ORIGIN = function( self, k )
            local dummy = self[k]; --force the variable to be loaded.
            return origin[k];
        end
    },
    {
        __index = function ( tbl, k )
            if origin[k] ~= nil then
                return nil;
            end

            local args, list, v = args, cfg.aliases[k];

            if type( list ) == 'table' then
                v, origin[k] = select_one( args, list, 'redundant_parameters' );
                if origin[k] == nil then
                    origin[k] = ''; -- Empty string, not nil
                end
            elseif list ~= nil then
                v, origin[k] = args[list], list;
            else
                -- maybe let through instead of raising an error?
                -- v, origin[k] = args[k], k;
                error( cfg.messages['unknown_argument_map'] );
            end

            -- Empty strings, not nil;
            if v == nil then
                v = cfg.defaults[k] or '';
                origin[k] = '';
            end

            tbl = rawset( tbl, k, v );
            return v;
        end,
    });
end

--[[ ===============================================================================
Controlla che il nome di un parametro sia valido usando la whitelist
    ===============================================================================]]
local function validate( name )
    name = tostring( name );
    -- Normal arguments
    if whitelist.basic_arguments[ name ] then return true end
    -- Arguments with numbers in them
    name = name:gsub( "%d+", "#" );
    if whitelist.numbered_arguments[ name ] then return true end
    -- Not found, argument not supported.
    return false
end

--[[ ===============================================================================
Oggetto per memorizzare gli elementi di una citazione. Un frammento di citazione è
formato dai seguenti elementi:
- self[n]: n-esimo elemento da unire, è una lista di stringhe inframezzata dai
            separatori da usare per unirle.
- self.last_priority: priorità del separatore di chiusura
- self.first_priority: priorità del separatore di apertura
- self.sep_key: codice del carattere separatore di default da usare
                se unita a un altro frammento    
===============================================================================]]
local Fragment = {}

Fragment.priority = {}
local Fragment_mt = { __index = Fragment }

Fragment.new = function(texts, sep_key)
    if type(texts) == "string" then texts = { texts } end
    local fpriority = Fragment.priority
    if not fpriority[sep_key] then sep_key = "" end
    local separator = fpriority[sep_key]
    local tx = { }
    tx.last_priority = 0
    tx.first_priority = 0
    tx.sep_key = sep_key
    tx[1] = ""
    for _, el in ipairs(texts) do
        if el ~= "" then
            tx[#tx+1] = el
            tx[#tx+1] = fpriority[tx.sep_key].sep
        end
    end
    if #tx > 1 then
        tx.last_priority = fpriority[tx.sep_key].order
    else
        tx[1] = ""
    end
    setmetatable(tx, Fragment_mt)
    return tx
end

--- cambia il separatore iniziale di un frammento di citazione
function Fragment:start(sep_key)
    if #self == 0 then return self end
    local separator = Fragment.priority[sep_key] or Fragment.priority[""]
    self[1] = separator.sep
    self.first_priority = separator.order
    return self
end

-- cambia il separatore finale di un frammento di citazione
function Fragment:last(sep_key)
    if #self == 0 then return self end
    local separator = Fragment.priority[sep_key] or Fragment.priority[""]
    self[#self] = separator.sep
    self.last_priority = separator.order
    return self
end

-- ritorna un frammento di citazione vuoto
function Fragment:empty()
    return #self==0
end

-- appende una stringa o un frammento di citazione in coda
function Fragment:append(txr)
    if txr == nil then return self end
    if type(txr) == "string" then txr = Fragment.new(txr, self.sep_key) end
    if #txr == 0 then return self end
    if #self == 0 then self[1] = txr[1] end
    self.last_priority = self.last_priority or 0
    if self.last_priority < txr.first_priority then
        self[#self] = txr[1]
    end
    for i, el in ipairs(txr) do
        if i>1 then self[#self+1] = el end
    end
    self.last_priority = txr.last_priority
    --self.sep_key = txr.sep_key
    return self
end

-- appende una lista di stringhe o frammenti di citazione
function Fragment:appends(fragments)
    for _,f in ipairs(fragments) do
        self:append(f)
    end
    return self
end

-- collassa il frammento in una stringa e la restituisce
Fragment_mt.__tostring = function(tx)
    return table.concat(tx, '')
end
-- =====================================================================
-- Fine definizione oggetto Fragment
-- =====================================================================

--[[ ===============================================================================
Formatta un link esterno a un documento
- options.code_id: codice per il link (tra prefisso e suffisso)
- options.id: etichetta del link 
- options.encode: se true o nil l'url viene codificato (en:Percent-encoding)
- options.link: link alla voce wiki sul codice documento
- options.label: etichetta del link alla voce wiki sul codice documento
- option.separator: separatore tra codice e link (di default un no breaking space)
- options.prefix: prefisso dell'url
- options.suffis: suffisso dell'url (opzionale)
    ===============================================================================]]
local function external_link_id(options)
    local url_string = options.code_id or options.id;
    if options.encode == true or options.encode == nil then
        url_string = mw.uri.encode( url_string );
    end
    return mw.ustring.format( '[[%s|%s]]%s[%s%s%s %s]',
        options.link, options.label, options.separator or "&nbsp;",
        options.prefix, url_string, options.suffix or "",
        mw.text.nowiki(options.id)
    );
end

--[[ ===============================================================================
Formatta un wikilink interno
- options.id: id del documento
- options.encode: se true o nil l'url viene codificato (en:Percent-encoding)
- options.link: link alla voce wiki sul codice documento
- options.label: etichetta del link alla voce wiki sul codice documento
- option.separator: separatore tra codice e link (di default un no breaking space)
- options.prefix: prefisso del link
- options.suffis: suffisso del link (opzionale)
    ===============================================================================]]
local function internal_link_id(options)
    return mw.ustring.format( '[[%s|%s]]%s[[%s%s%s|%s]]',
        options.link, options.label, options.separator or "&nbsp;",
        options.prefix, options.id, options.suffix or "",
        mw.text.nowiki(options.id)
    );
end

--[[ ===============================================================================
Determina se un URL è corretto. Al momento controlla solo la stringa inizia con
prefisso URI valido e che non contenga spazi
TODO: aggiungere controlli più stringenti (vedi en.wiki)
    ===============================================================================]]
local function check_url( url_str )
    -- se contiene spazi non può essere un url corretto
    if nil == url_str:match ("^%S+$") then
        return false;
    end
    -- Protocol-relative or URL scheme
    return url_str:sub(1,2) == "//" or url_str:match( "^[^/]*:" ) ~= nil;
end

--[[ ===============================================================================
Rende una stringa sicura per essere usata come descrizione di un url
    ===============================================================================]]
local function safe_for_url( str )
    if str:match( "%[%[.-%]%]" ) ~= nil then
        table.insert( z.message_tail, { set_error( 'wikilink_in_url', {}, true ) } );
    end

    return str:gsub( '[%[%]\n]', {
        ['['] = '&#91;',
        [']'] = '&#93;',
        ['\n'] = ' ' } );
end

--[[ ===============================================================================
Formatta un collegamento esterno con controllo degli errori
- URL: url del link esterno
- label: etichetta del link esterno (se non inserita viene usato
         URL come etichetta e segnalato l'errore)
- source: parametro in cui è contenuto l'url
    ===============================================================================]]
local function external_link( URL, label, source )
    local error_str = "";
    if not is_set( label ) then
        label = URL;
        if is_set( source ) then
            error_str = set_error( 'bare_url_missing_title', { wrap( 'parameter', source ) }, false, " " );
        else
            error( cfg.messages["bare_url_no_origin"] );
        end
    end
    if not check_url( URL ) then
        error_str = set_error( 'bad_url', {}, false, " " ) .. error_str;
    end
    return table.concat({ "[", URL, " ", safe_for_url( label ), "]", error_str });
end

--[[ ===============================================================================
Ritorna la parte di una stringa data che rappresenta l'anno. Se non riesce ritorna
la stringa vuota
    ===============================================================================]]
local function select_year( str )
    -- Is the input a simple number?
    local num = tonumber( str );
    if num ~= nil and num > 0 and num < 2100 and num == math.floor(num) then
        return str;
    else
        -- Use formatDate to interpret more complicated formats
        local lang = mw.getContentLanguage();
        local good, result;
        good, result = pcall( lang.formatDate, lang, 'Y', str )
        if good then
            return result;
        else
            -- Can't make sense of this input, return blank.
            return "";
        end
    end
end

--[[ ===============================================================================
Formatta un DOI e controlla per errori
    ===============================================================================]]
local function doi(id, inactive)
    local cat = ""
    local handler = cfg.id_handlers['DOI'];

    local text;
    if is_set(inactive) then
        text = "[[" .. handler.link .. "|" .. handler.label .. "]]:" .. id;
        table.insert( z.error_categories, "Pagine con DOI inattivo dal " .. select_year(inactive) );
        inactive = " (" .. cfg.messages['inactive'] .. " " .. inactive .. ")"
    else
        text = external_link_id({link = handler.link, label = handler.label,
            prefix=handler.prefix,id=id,separator=handler.separator, encode=handler.encode})
        inactive = ""
    end
    if ( string.sub(id,1,3) ~= "10." ) then
        cat = set_error( 'bad_doi' );
    end
    return text .. inactive .. cat
end

--[[ ===============================================================================
Formatta un link a Open library e controlla per errori
    ===============================================================================]]
local function open_library(id)
    local code = id:sub(-1,-1)
    local handler = cfg.id_handlers['OL'];
    if ( code == "A" ) then
        return external_link_id({link=handler.link, label=handler.label,
            prefix="http://openlibrary.org/authors/OL",id=id, separator=handler.separator,
            encode = handler.encode})
    elseif ( code == "M" ) then
        return external_link_id({link=handler.link, label=handler.label,
            prefix="http://openlibrary.org/books/OL",id=id, separator=handler.separator,
            encode = handler.encode})
    elseif ( code == "W" ) then
        return external_link_id({link=handler.link, label=handler.label,
            prefix= "http://openlibrary.org/works/OL",id=id, separator=handler.separator,
            encode = handler.encode})
    else
        return external_link_id({link=handler.link, label=handler.label,
            prefix= "http://openlibrary.org/OL",id=id, separator=handler.separator,
            encode = handler.encode}) ..
            ' ' .. set_error( 'bad_ol' );
    end
end

--[[ ===============================================================================
Formatta un link alla libreria Opac mediante SBN e controlla per errori
    ===============================================================================]]
local function sbn(id)
    local handler = cfg.id_handlers['SBN']
    local start_match, end_match, cd1, cd2 = string.find(id, '^IT\\ICCU\\(...)\\(%d+)')
    if not(cd1 and cd2) then
        start_match, end_match, cd1, cd2 = string.find(id, '^IT\\ICCU\\(....)\\(%d+)')
    end
    if cd1 and cd2 then
        return external_link_id({link=handler.link, label=handler.label,
            prefix='http://opac.sbn.it/bid/', id = id, code_id=cd1 .. cd2,
            encode =handler.encode})
    else
        return external_link_id({link=handler.link, label=handler.label,
            prefix='http://opac.sbn.it/bid/', id = id,
            encode =handler.encode}) .. ' ' .. set_error('bad_sbn')
    end
end

--[[ ===============================================================================
    Nice Opaque Identifiern utilisé par les formats Ark pour générer une clé
    adattato da fr:Module:Biblio/Références
    ===============================================================================]]
local function ark_id( base )
    base = tostring( base )
    if base then
        local xdigits = '0123456789bcdfghjkmnpqrstvwxz'
        local sum = 0 
        local position
        for i = 1, base:len() do
            position = xdigits:find( base:sub( i, i ), 1, true ) or 1
            sum = sum + i * ( position - 1 )
        end
        local index = sum % 29 + 1
        return xdigits:sub( index, index )
    end
end

--[[ ===============================================================================
    Formatta un link alla Bibliothèque Nationale de France e controlla per errori
    adattato da fr:Module:Biblio/Références
    ===============================================================================]]
local function bnf(id)
    local handler = cfg.id_handlers['BNF']
    if id then
        local txt = id
        local error_code = ''
        local bnf_id = id:upper():match( 'BNF(%d+%w)' ) or id:lower():match( 'cb(%d+%w)' ) or id:match( '^%d+%w' )
        
        if bnf_id then
            -- bnf contient une suite de chiffres qui peut être un ark valide
            local base = bnf_id:sub( 1, 8 )
            if bnf_id:len() == 8 then 
                -- il manque la clé, on l'ajoute
                id = base .. ark_id( 'cb' .. base )
                txt = base
            elseif bnf_id:len() > 8 and bnf_id:sub( 9, 9 ) == ark_id( 'cb' .. base ) then
                -- ark valide
                id = bnf_id:sub( 1, 9 )
                txt = base
            else
                -- ark qui semble non valide
                id = bnf_id
                txt = bnf_id
                error_code = set_error('bad_bnf')
            end
        else
            -- le paramètre ne semble pas un ark valide
            error_code = set_error('bad_bnf')
        end
        
        -- dans tous les cas on renvoie l'adresse, on catégorise juste pour vérifier ce qui ne va pas
        return external_link_id({link=handler.link, label=handler.label, prefix=handler.prefix,
                            id=txt, code_id=bnf_id, separator=handler.separator}) .. ' ' .. error_code
    end
end

--[[ ===============================================================================
Rimuove text e trattini irrilevanti da un numero isbn
    ===============================================================================]]
local function clean_isbn( isbn_str )
    return isbn_str:gsub( "[^-0-9X]", "" );
end

--[[ ===============================================================================
Determina se una stringa ISBN è valida
    ===============================================================================]]
local function check_isbn( isbn_str )
    isbn_str = clean_isbn( isbn_str ):gsub( "-", "" );

    local len = isbn_str:len();

    if len ~= 10 and len ~= 13 then
        return false;
    end
    local temp = 0;
    if len == 10 then
        if isbn_str:match( "^%d*X?$" ) == nil then return false; end
        isbn_str = { isbn_str:byte(1, len) };
        for i, v in ipairs( isbn_str ) do
            if v == string.byte( "X" ) then
                temp = temp + 10*( 11 - i );
            else
                temp = temp + tonumber( string.char(v) )*(11-i);
            end
        end
        return temp % 11 == 0;
    else
        if isbn_str:match( "^%d*$" ) == nil then return false; end
        isbn_str = { isbn_str:byte(1, len) };
        for i, v in ipairs( isbn_str ) do
            temp = temp + (3 - 2*(i % 2)) * tonumber( string.char(v) );
        end
        return temp % 10 == 0;
    end
end

--[[ ===============================================================================
Ritorna la sola etichetta visibile di un wikilink
    ===============================================================================]]
local function remove_wikilink( str )
    -- Sia [[A|B]] che [[B]] ritornano B
    return (str:gsub( "%[%[([^%[%]]*)%]%]", function(l)
        return l:gsub( "^[^|]*|(.*)$", "%1" ):gsub("^%s*(.-)%s*$", "%1");
    end));
end

--[[ ===============================================================================
Ritorna una data e controlla se è nel formato ISO yyyy-mm-dd e in questo caso la
riformatta come dd mmmm yyyy
    ===============================================================================]]
local function get_date(str)
    if is_set(str) then
        local _, _, try_year, try_month, try_day = string.find(str, '^(%d%d%d%d)-(%d%d)-(%d%d)$')
        if try_day then
            local Month = cfg.months[tonumber(try_month)]
            if Month then
                if try_day == "01" then try_day="1°" end
                return string.format("%s %s %s", try_day, Month, try_year )
            end
        end
    end
    return str
end

--[[ ===============================================================================
Unisce year, day e month ritornando la data come un'unica stringa.
month è controllato solo se year è definito, e day è controllato solo se month è definito.
Se month è un numero tenta di convertilo nel nome corrispondente (1->gennaio, 2->febbraio...),
altrimenti non lo modifica
    ===============================================================================]]
local function get_date_yyyy_mm_dd(year, month, day)
    local date = year
    if is_set(date) then
        if is_set(month) then
            local month = cfg.months[tonumber(month)] or month
            date = month .. " " .. year
            if is_set(day) then
                if day == "01" or day=="1" then day="1°" end
                date = day .. " " .. date
            end
        end
        return date
    end
    return ""
end

--[[ ===============================================================================
Suppone che str sia una data ben formata (una delle varianti "gg mm aaaa",
"gg/mm/aaaa" o "gg-mm-aaaa") e restituisce l'articolo da anteporre per citarla
come data di accesso/archivio
    ===============================================================================]]
local function article_date(str)
    local start = mw.ustring.sub(str, 1, 2)
    if in_array( start, {'08', '8 ', '8-', '8/', '11'} ) then
        return "l'"
    end
    return "il "
end

--[[ ===============================================================================
Controlla che la stringa passata sia in un formato ammesso in caso contrario
 ritorna il codice di errore
    ===============================================================================]]
local function check_time(str)
    local h,m,s = string.match(str, '^(%d+):(%d+):(%d+)$')
    if not(h) then h,m,s = string.match(str, '^(%d+) h (%d+) min (%d+) s$') end
    if not(m) then m,s = string.match(str, '^(%d+) min (%d+) s$') end
    if not(m) then m,s = string.match(str, '^(%d+):(%d+)$') end
    if not(m) then m = string.match(str, '^(%d+) min$') end
    if not(m) then return 'time_not_valid' end
    if tonumber(m) >= 60 then return 'minutes_wrong' end
    if s and tonumber(s) >= 60 then return 'seconds_wrong' end
    if h and not(tonumber(s)) then return 'hour_wrong' end
    return nil
end

--[[ ===============================================================================
Formatta una lista di persone (autori o editori)
    ===============================================================================]]
local function list_people(control, people)
    local sep = control.sep;
    local lastsep = control.lastsep
    local text = {}
    local etal = control.etal
    local coauthors = control.coauthors
    local person_list = {}

    for i,person in ipairs(people) do
        local last = person.last
        if is_set(last) then
            local fullname = ""
            local first = person.first
            if is_set(first) then
                if invertorder then first, last = last, first end
                fullname = table.concat({first, person.last}, ' ')
            else
                fullname = person.last
            end
            if is_set(person.link) then fullname = table.concat({"[[", person.link, "|", fullname, "]]"}) end
            table.insert( person_list, fullname )
        end
        if etal then
            break
        end
    end
    local count = #person_list
    local result = ""
     if count > 0 then
        if coauthors then
            result = table.concat(person_list, sep)
        elseif etal then
            result = person_list[1] .. cfg.messages['et al']
        else
            result = mw.text.listToText(person_list, sep, lastsep)
        end
    end
    return result, count
end

--[[ ===============================================================================
Genera un id per un ancora CITEREF
    ===============================================================================]]
local function anchor_id( options )
    return "CITEREF" .. table.concat( options );
end

--[[ ===============================================================================
Estrae una lista di nomi (autori o editori) dalla lista argomenti
    ===============================================================================]]
local function extract_names(args, list_name)
    local names = {};
    local i = 1;
    local last;

    while true do
        last = select_one( args, cfg.aliases[list_name .. '-Last'], 'redundant_parameters', i );
        if not is_set(last) then
            local first = select_one( args, cfg.aliases[list_name .. '-First'], 'redundant_parameters', i )
            if not is_set(first) then
                break;
            else -- nel caso sia definito "nome" ma non "cognome"
                names[i] = {
                    last = first,
                    first = '',
                    link = select_one( args, cfg.aliases[list_name .. '-Link'], 'redundant_parameters', i ),
                }
            end
        else
            names[i] = {
                last = last,
                first = select_one( args, cfg.aliases[list_name .. '-First'], 'redundant_parameters', i ),
                link = select_one( args, cfg.aliases[list_name .. '-Link'], 'redundant_parameters', i ),
            };
        end
        i = i + 1;
    end
    return names;
end

--[[ ===============================================================================
Estrae dagli argomenti i codici bibliografici riconosciuti usando la
tabella cfg.id_handlers
    ===============================================================================]]
local function extract_ids( args )
    local id_list = {};
    for k, v in pairs( cfg.id_handlers ) do
        v = select_one( args, v.parameters, 'redundant_parameters' );
        if is_set(v) then
            if k == 'ISBN' then v = string.gsub(v, '^ISBN%s*', '') end -- hack per eliminare l'ISBN ripetuto
            id_list[k] = v;
        end
    end
    return id_list;
end

--[[ ===============================================================================
Formatta gli id bibliografici presenti nella tabella id_list
    ===============================================================================]]
local function build_id_list( id_list, options )
    local new_list, handler = {};

    local function fallback(k)
        return { __index = function(t,i) return cfg.id_handlers[k][i] end }
    end;

    local function comp( a, b )
        return a[1] < b[1];
    end

    for k, v in pairs( id_list ) do
        -- fallback to read-only cfg
        local handler = setmetatable( { ['id'] = v }, fallback(k) );

        if handler.mode == 'external' then
            table.insert( new_list, {handler.label, external_link_id( handler ) } );
        elseif handler.mode == 'internal' then
            table.insert( new_list, {handler.label, internal_link_id( handler ) } );
        elseif handler.mode ~= 'manual' then
            error( cfg.messages['unknown_ID_mode'] );
        elseif k == 'DOI' then
            table.insert( new_list, {handler.label, doi( v, options.DoiBroken ) } );
        elseif k == 'OL' then
            table.insert( new_list, {handler.label, open_library( v ) } );
        elseif k == 'SBN' then
            table.insert (new_list, {handler.label, sbn(v) } );
        elseif k == 'BNF' then
            table.insert (new_list, {handler.label, bnf(v) } );
        elseif k == 'ISBN' then
            local ISBN
            if v == 'non esistente' or v == 'no' then --la forma lunga per intercettare il valore ritornato dal template NoIsbn
                ISBN = 'ISBN non esistente'
            else
                ISBN = internal_link_id( handler );
                if not check_isbn( v ) and not is_set(options.IgnoreISBN) then
                    ISBN = ISBN .. set_error( 'bad_isbn', {}, false, "<sup>", "</sup>" );
                end
            end
            table.insert( new_list, {handler.label, ISBN } );
        else
            error( cfg.messages['unknown_manual_ID'] );
        end
    end
    table.sort( new_list, comp );
    for k, v in ipairs( new_list ) do
        new_list[k] = v[2];
    end

    return new_list;
end

--[[ ===============================================================================
Genera la citazione
    ===============================================================================]]
local function citation0( config, args)
    local A = argument_wrapper( args );
    local i

    local Stylename = A['Style']
    local Style = cfg.style
    local PPPrefix = (is_set( A['NoPP'] ) and "") or Style.ppprefix
    local PPrefix = (is_set( A['NoPP'] ) and "") or Style.pprefix
    Fragment.priority = Style.separator_priority
    -- Pick out the relevant fields from the arguments. Different citation templates
    -- define different field names for the same underlying things.
    -- local Authors = A['Authors'];
    local a = extract_names( args, 'AuthorList' );

    local Coauthors = A['Coauthors'];
    local Others = A['Others'];
    local Editors = A['Editors'];
    local e = extract_names( args, 'EditorList' );

    ------------------------------------------------- Get date data
    local PublicationDate = A['PublicationDate'];
    local LayDate = A['LayDate'];
    ------------------------------------------------- Get title data
    local Title = A['Title'];
    local Conference = A['Conference'];
    local Organization = A['Organization']
    local TransTitle = A['TransTitle'];
    local OriginalTitle = A['OriginalTitle']
    -- local TitleNote = A['TitleNote'];
    local TitleLink = A['TitleLink'];
    local Chapter = A['Chapter'];
    local ChapterLink = A['ChapterLink'];
    local TransChapter = A['TransChapter'];
    local TitleType = A['TitleType'];
    local ArchiveURL = A['ArchiveURL'];
    local URL = A['URL']
    local URLorigin = A:ORIGIN('URL');
    local ChapterURL = A['ChapterURL'];
    local ChapterURLorigin = A:ORIGIN('ChapterURL');
    local ConferenceURL = A['ConferenceURL'];
    local ConferenceURLorigin = A:ORIGIN('ConferenceURL');
    local Abstract = A['Abstract']
    local Periodical = A['Periodical'];

    if is_set(OriginalTitle) and not is_set(TransTitle) then
        TransTitle = Title
        Title = OriginalTitle
    end

    local isPubblicazione = (config.CitationClass == 'pubblicazione') or
                            (config.CitationClass=='testo' and is_set(Periodical))

    ------------------------------------------------------------------------------
    -- Formattazione di Position - contiene la pagina/posizione o punto del video
    -- a cui fa riferimento la fonte
    ------------------------------------------------------------------------------
    local Position = A['Position'];
    local PositionOrigin=A:ORIGIN('Position')
    if is_set(Position) then
        if PositionOrigin == "p" then
            Position = PPrefix .. Position
        elseif PositionOrigin == "pp" then
            Position = PPPrefix .. Position
        elseif PositionOrigin ~= "posizione" then
            if config.CitationClass == "libro" and PositionOrigin=="pagine" then
                if tonumber(Position) then
                    Position = PPrefix .. Position
                elseif string.find(Position, '^%d') then
                    Position = PPPrefix .. Position
                end
            elseif (config.CitationClass=="conferenza" or config.CitationClass== "pubblicazione") and PositionOrigin=="pagine" then
                if tonumber(Position) then
                    Position = PPrefix .. Position
                else
                    Position = PPPrefix .. Position
                end
            elseif PositionOrigin == "pagina" then
                Position = PPrefix .. Position
            else
                Position = PPPrefix .. Position
            end
        end
    end
    local Hour = A['Hour']
    local Minutes = A['Minutes']
    local Seconds = A['Seconds']
    local Time = A['Time']
    if in_array(config.CitationClass, { "video", "tv", "audio" } ) then
        local ComposeTime = {}
        local TimeError = {}
        if is_set(Hour) then
            if not is_set(Minutes) then TimeError[#TimeError+1] = set_error('need_minutes' , {'ora'}) end
            if not tonumber(Hour) then TimeError[#TimeError+1] = set_error('timepar_must_be_integer', {'ora'}) end
            ComposeTime[#ComposeTime+1] = Hour .. '&nbsp;h'
        end
        if is_set(Minutes) then
            local check_error = tonumber(Minutes)
            if not check_error then
                TimeError[#TimeError+1] = set_error('timepar_must_be_integer', {'minuto'})
            elseif check_error > 60 then
                TimeError[#TimeError+1] = set_error('minutes_wrong')
            end    
            ComposeTime[#ComposeTime+1] = Minutes .. '&nbsp;min'
        end
        if is_set(Seconds) then
            if not is_set(Minutes) then TimeError[#TimeError+1] = set_error('need_minutes', {'secondo'}) end
            local check_error = tonumber(Seconds)
            if not check_error then
                TimeError[#TimeError+1] = set_error('timepar_must_be_integer', {'ora'})
            elseif check_error > 60 then
                TimeError[#TimeError+1] = set_error('seconds_wrong')
            end
            ComposeTime[#ComposeTime+1] = Seconds .. '&nbsp;s'
        end
        if #ComposeTime > 1 then
            if is_set(Position) then TimeError[#TimeError+1] = set_error('time_parameter_conflict') end
            Position = 'a ' .. table.concat(ComposeTime, '&nbsp;')
        end
        if is_set(Time) then
            if is_set(Position) then TimeError[#TimeError+1] = set_error('time_parameter_conflict') end
            local check_error = check_time(Time)
            if check_error then TimeError[#TimeError+1] = set_error(check_error) end
            Position = 'a ' .. Time
        end
        if #TimeError > 0 then Position = Position .. " " .. table.concat(TimeError, ", ") end
    else
        if is_set(Hour) or is_set(Minutes) or is_set(Seconds) or is_set(Time) then
            table.insert( z.message_tail, { set_error( 'not_video_citation', {}, true ) } );
        end
    end
    if is_set(Position) then Position = ' ' .. Position end

    ------------------------------------------------------------------------------
    -- Formattazione di volume/numero/serie/episodio
    ------------------------------------------------------------------------------
    local Series = A['Series'];
    local Volume = A['Volume'];
    local Issue = A['Issue'];
    if config.CitationClass == "tv" then
        if is_set(Issue) then
            if is_set(Volume) then
                Issue = substitute(cfg.messages['season_episode'], {Volume, Issue} )
                Volume = ''
            else
                Issue = substitute(cfg.messages['episode'], {Issue})
            end
        end
    else
        if is_set(Volume) then
            if tonumber(Volume) or A:ORIGIN('Volume') == "vol" then
                Volume = "vol.&nbsp;" .. Volume
            end
        end
        if is_set(Issue) then
            if tonumber(Issue) then
                Issue = "nº&nbsp;" .. Issue
            end
        end
    end

    local Edition = A['Edition'];
    local Place = A['Place']
    local PublisherName = A['PublisherName'];
    local SubscriptionRequired = A['SubscriptionRequired'];
    local Via = A['Via'];
    -- local Agency = A['Agency'];
    local DeadURL = A['DeadURL']
    local Language = A['Language'];
    local Format = A['Format'];
    local Ref = A['Ref'];

    local DoiBroken = A['DoiBroken'];
    local ID = A['ID'];
    local IgnoreISBN = A['IgnoreISBN'];
    local Quote = A['Quote'];
    local sepc = Style.sep
    local sepcspace = sepc .. " "
    local PostScript = first_set(A['PostScript'], Style['postscript'])
    local no_tracking_cats = A['NoTracking'];
    local use_lowercase = ( sepc ~= '.' );
    local this_page = mw.title.getCurrentTitle(); --Also used for COinS

    local ID_list = extract_ids( args );
    if ( isPubblicazione ) then
        if not is_set(URL) and is_set(ID_list['PMC']) then
            local Embargo = A['Embargo'];
            if is_set(Embargo) then
                local lang = mw.getContentLanguage();
                local good1, result1, good2, result2;
                good1, result1 = pcall( lang.formatDate, lang, 'U', Embargo );
                good2, result2 = pcall( lang.formatDate, lang, 'U' );

                if good1 and good2 and tonumber( result1 ) < tonumber( result2 ) then
                    URL = "http://www.ncbi.nlm.nih.gov/pmc/articles/PMC" .. ID_list['PMC'];
                    URLorigin = cfg.id_handlers['PMC'].parameters[1];
                end
            else
                URL = "http://www.ncbi.nlm.nih.gov/pmc/articles/PMC" .. ID_list['PMC'];
                URLorigin = cfg.id_handlers['PMC'].parameters[1];
            end
        end
    end
    ID_list = build_id_list( ID_list, {DoiBroken = DoiBroken, IgnoreISBN = IgnoreISBN} );

    local Station = A['Station'];
    if is_set(Station) then
        local wkStation = A['StationLink']
        if is_set(wkStation) then
            Station = '[[' .. wkStation .. '|' .. Station .. ']]'
        end
    end
    if config.CitationClass == "tv" then
        Chapter = Title;
        ChapterLink = TitleLink;
        TransChapter = TransTitle;
        Title = Series;
        TitleLink = A['SeriesLink'];
        TransTitle = '';
        Series = '';
    end

    ------------------------------------------------------------------------------
    -- Se compare uno dei parametri legati a una pubblicazione periodica (opera, rivista, ec...)
    -- e non è definito capitolo, ma solo titolo sposto titolo a capitolo
    ------------------------------------------------------------------------------
    if is_set(Periodical) and not is_set(Chapter) and is_set(Title) then
        Chapter = Title;
        ChapterLink = TitleLink;
        TransChapter = TransTitle;
        Title = '';
        TitleLink = '';
        TransTitle = '';
    end

    ------------------------------------------------------------------------------
    -- Se opera/sito non è specificata, nel caso dei siti usa il dominio dell'URL
    ------------------------------------------------------------------------------
    if config.CitationClass == "web" and not is_set(Periodical) and not is_set(PublisherName) and is_set(URL) then
        Periodical = mw.ustring.match(URL, "//([^/#%?]*)") or ''
        -- tolgo anche eventuale www.
        if string.find(Periodical, "^[Ww][Ww][Ww]%.") then
            Periodical = mw.ustring.sub(Periodical, 5)
        end
        -- evito ripetizione se il dominio è stato usato come titolo o editore
        if Periodical and mw.ustring.lower(Title or '') == mw.ustring.lower(Periodical) then
            Periodical = nil
        end
    end

    ------------------------------------------------------------------------------
    -- Recupero e formatto lista autori
    ------------------------------------------------------------------------------
    local AuthorSeparator = Style.peoplesep
    local control = {
        sep = AuthorSeparator,
        maximum = Style.maximum_authors,
        lastsep = Style.lastsepauthor,
        invertorder = Style.invertorder,
        etal = false,
        coauthors = false,
    };
    local Etal = A['Etal']
    -- If the coauthor field is also used, prevent adding ''et al.''
    if is_set(Coauthors) then
        control.coauthors = true
    elseif is_set(Etal) then
        control.etal = true
    end
    local Authors = list_people(control, a)
    if not is_set(Authors) and is_set(Coauthors) then -- se non sono stati compilati campi autore, ma solo coautori
        Authors = Coauthors
        Coauthors = ""
    elseif is_set(Coauthors) then
        Authors = table.concat({Authors, AuthorSeparator, Coauthors})
    end

    ------------------------------------------------------------------------------
    -- Recupero e formatto lista curatori
    ------------------------------------------------------------------------------
    local EditorCount, msg_editors
    local CuratoriEtal = A['Etalcuratori']
    control.coauthors = false
    if is_set(CuratoriEtal) then
        control.etal = true
    else
        control.etal = false
    end
    if is_set(Editors) then
        msg_editors = 'editors'
    else
        Editors, EditorCount = list_people(control, e)
        if is_set(Editors) then
            if EditorCount <= 1 then msg_editors = 'editor' else msg_editors = 'editors' end
        end
    end
    ------------------------------------------------------------------------------
    -- Se non sono definiti autori sostituisco con curatori
    ------------------------------------------------------------------------------
    if not is_set(Authors) and is_set(Editors) then
        Authors = Editors
        Editors = ""
    end

    ------------------------------------------------------------------------------
    -- Se conferenza aggiungo il campo Organizzazione
    ------------------------------------------------------------------------------
    if config.CitationClass == 'conferenza' then
        if is_set (Authors) and is_set(Organization) then
            Authors = table.concat({Authors, ', ', Organization})
        elseif is_set(Organization) then
            Authors = Organization
        end
        Organization = ""
    end

    ------------------------------------------------------------------------------
    -- Formatto la data
    ------------------------------------------------------------------------------
    local Date = get_date(A['Date'])
    local Year = A['Year']
    if not is_set(Date) then Date=get_date_yyyy_mm_dd(Year, A['Month'], A['Day']) end
    local OrigDate = get_date(A['OrigDate'])
    if not is_set(OrigDate) then OrigDate=get_date_yyyy_mm_dd(A['OrigYear'], A['OrigMonth'], A['OrigDay']) end
    local AccessDate = get_date(A['AccessDate'])
    if not is_set(AccessDate) then AccessDate=get_date_yyyy_mm_dd(A['AccessYear'], A['AccessMonth'], A['AccessDay']) end
    local ArchiveDate = get_date(A['ArchiveDate']);
    if is_set(OrigDate) and not is_set(Date) then
        Date = OrigDate
        OrigDate = ""
    end
    OrigDate = is_set(OrigDate) and (" " .. wrap( 'origdate', OrigDate)) or "";

    if in_array(PublicationDate, {Date, Year}) then PublicationDate = '' end
    if not is_set(Date) and is_set(PublicationDate) then
        Date = PublicationDate;
        PublicationDate = '';
    end

    -- Captures the value for Date prior to adding parens or other textual transformations
    local DateIn = Date;
    if not is_set(URL) and
        not is_set(ChapterURL) and
        not is_set(ArchiveURL) and
        not is_set(ConferenceURL) then
        -- Test if cite web is called without giving a URL
        if ( config.CitationClass == "web" ) then
            table.insert( z.message_tail, { set_error( 'cite_web_url', {}, true ) } );
        end
        -- Test if accessdate is given without giving a URL
        if is_set(AccessDate) then
            table.insert( z.message_tail, { set_error( 'accessdate_missing_url', {}, true ) } );
            AccessDate = '';
        end
        -- Test if format is given without giving a URL
        if is_set(Format) then
            Format = Format .. set_error( 'format_missing_url' );
        end
    end

    -- Test if citation has no title
    if not is_set(Chapter) and
        not is_set(Title) and
        not is_set(Periodical) and
        not is_set(Conference) and
        not is_set(TransTitle) and
        not is_set(TransChapter) then
        table.insert( z.message_tail, { set_error( 'citation_missing_title', {}, true ) } );
    end

    -- Se il formato file non è specificato, prova a ricavarlo dalla fine dell'URL
    if (is_set(URL) or is_set(ChapterURL)) and not is_set(Format) then
        local try_format = mw.ustring.match( (is_set(ChapterURL) and ChapterURL) or URL, "^.*%.(.+)$" ) or ''
        if cfg.external_link_type[try_format:lower()] then
            Format = try_format
        end
    end

    -- Se il formato esterno è tra quelli previsti imita lo stile dei template {{PDF}} o {{doc}}
    if is_set(Format) then
        local f = cfg.external_link_type[Format:lower()]
        if f then
            Format = mw.ustring.format(' (<span style="font-weight: bolder; font-size: smaller;>[[%s|%s]]</span>)', f.link, f.label)
        else
            table.insert( z.message_tail, { set_error('unknown_format', Format, true) } );
            Format = mw.ustring.format(' (%s)', Format)
        end
    else
        Format = ""
    end

    local OriginalURL = URL
    DeadURL = DeadURL:lower();
    if is_set( ArchiveURL ) then
        if ( DeadURL ~= "no" ) then
            URL = ArchiveURL
            URLorigin = A:ORIGIN('ArchiveURL')
        end
    end

    ---------------------------------------------------------------
    -- se pubblicazione controlla per i parametro abstract
    --------------------------------------------------------------
    if is_set(Abstract) then
        if isPubblicazione then
            if is_set(ChapterURL) then
                TitleType = external_link( ChapterURL, 'abstract' )
                ChapterURL = ""
                if not is_set(URL) then Format = "" end
            elseif is_set(URL) then
                TitleType = external_link( URL, 'abstract' )
                URL = ""
            else
                Abstract = ''
            end
        else
            Abstract = ""
        end
    else
        Abstract = ""
    end
    TitleType = is_set(TitleType) and ("(" .. TitleType .. ")") or "";

    ---------------------------------------------------------------
    -- Format chapter / article title
    ---------------------------------------------------------------
    local TransError = ""
    if is_set(TransChapter) then
        if not is_set(Chapter) then
            TransError = " " .. set_error( 'trans_missing_chapter' )
            Chapter = TransChapter
            TransChapter = ""
        else
            TransChapter = wrap( 'trans-italic-title', TransChapter )
        end
    end
    Chapter = wrap( 'italic-title', Chapter );
    if is_set(TransChapter) then Chapter = Chapter .. " " .. TransChapter end
    if is_set(Chapter) then
        if is_set(ChapterLink) then
            Chapter = table.concat({"[[", ChapterLink, "|", Chapter, "]]"})
        elseif is_set(ChapterURL) then
                Chapter = external_link( ChapterURL, Chapter ) .. TransError;
                if not is_set(URL) then --se è settato URL conservo Format per inserirlo dopo questo
                    Chapter = Chapter .. Format;
                    Format = "";
                end
        elseif is_set(URL) then
            Chapter = external_link( URL, Chapter ) .. TransError .. Format;
            URL = "";
            Format = "";
        else
            Chapter = Chapter .. TransError;
        end
    elseif is_set(ChapterURL) then
        Chapter = external_link( ChapterURL, nil, ChapterURLorigin ) .. TransError
    end

    ---------------------------------------------------------------
    -- Format main title
    ---------------------------------------------------------------
    TransError = "";
    if is_set(TransTitle) then
        if not is_set(Title) then
            TransError = " " .. set_error( 'trans_missing_title' )
            Title = TransTitle
            TransTitle = ""
        else
            TransTitle = wrap( 'trans-italic-title', TransTitle )
        end
    end
    Title = wrap('italic-title', Title )
    if is_set(TransTitle) then Title = Title .. " " .. TransTitle end
    if is_set(Title) then
        if is_set(TitleLink) then
            Title = "[[" .. TitleLink .. "|" .. Title .. "]]"
        elseif is_set(URL) then
            Title = external_link( URL, Title ) .. TransError .. Format
            URL = "";
            Format = "";
        else
            Title = Title .. TransError;
        end
    end
    ---------------------------------------------------------------
    -- Format Conference
    ---------------------------------------------------------------
    if is_set(Conference) then
        Conference = wrap('italic-title', Conference )
        if is_set(ConferenceURL) then
            Conference = external_link( ConferenceURL, Conference );
        end
    elseif is_set(ConferenceURL) then
        Conference = external_link( ConferenceURL, nil, ConferenceURLorigin );
    end

    ---------------------------------------------------------------
    -- Compone la stringa del linguaggio
    ---------------------------------------------------------------
    local Language_code = ""
    if is_set(Language) then
        if Language:sub(1,1) == "(" then
            Language_code = Language
        else
            local frame = {return_error='true', usacodice='sì'}
            for lingua in mw.ustring.gmatch(Language, "%S+") do
                frame[#frame+1] = lingua
            end
            if #frame > 1 or (#frame==1 and frame[1]:lower()~="it") then
                local lg_error
                local lg = require( "Modulo:Linguaggi" );
                Language_code, lg_error = lg.lingue(frame)
                if lg_error and #lg_error > 0 then
                    local error_string = mw.text.listToText(lg_error, ", ", " e " )
                    table.insert( z.message_tail, { set_error('unknown_language', {error_string}, true) } );
                end
            end
        end
    end

    if is_set(Edition) then
        if A:ORIGIN('Edition') == "ed" or tonumber(Edition) then
            Edition = Edition .. "ª&nbsp;ed."
        end
    end

    -- se URL non è stato consumato da un capitolo/titolo emette errore
    if is_set(URL) then
        URL = " " .. external_link( URL, nil, URLorigin );
    end

    --Aggiungo le virgolette alla citazione-
    if is_set(Quote) then
        Quote = wrap( 'quoted-text', Quote );
    end
    ---------------------------------------------------------------
    -- Parametro via e subscription
    ---------------------------------------------------------------
    if is_set(Via) then
        if is_set(SubscriptionRequired) then
            Via = wrap( 'viasubscription', Via );
        else
            Via = wrap('via', Via);
        end
    elseif is_set(SubscriptionRequired) then
        Via = wrap('subscription')
    end

    ---------------------------------------------------------------
    -- Formattazione dati di accesso/url di archivio
    ---------------------------------------------------------------
    if is_set(AccessDate) then
        AccessDate = substitute( cfg.messages['retrieved'], {AccessDate, article_date(AccessDate)} )
    end
    local Archived
    if is_set(ArchiveURL) then
        if not is_set(ArchiveDate) then
            ArchiveDate = set_error('archive_missing_date');
        end
        ArchiveURL2 = A['ArchiveURL2']
        if is_set(ArchiveURL2) then
            ArchiveDate2 = A['ArchiveDate2']
            if not is_set(ArchiveDate2) then
                ArchiveDate2 = set_error('archive_missing_date2');
            end
        end
        if DeadURL=="no" then
            Archived = substitute( cfg.messages['archived-not-dead'],
                    { external_link( ArchiveURL, cfg.messages['archived'] ), ArchiveDate, article_date(ArchiveDate) } );
            if not is_set(OriginalURL) then
                Archived = Archived .. " " .. set_error('archive_missing_url');
            end
        elseif is_set(OriginalURL) then
            Archived = substitute( cfg.messages['archived-dead'],
                { OriginalURL, ArchiveDate, article_date(ArchiveDate) } );
        else
            Archived = substitute( cfg.messages['archived-missing'],
                { set_error('archive_missing_url'), ArchiveDate, article_date(ArchiveDate) } );
        end
        if is_set(ArchiveURL2) then
            Archived = Archived .. ". " .. substitute(cfg.messages['archived-second-copy'],
                        { external_link( ArchiveURL2, cfg.messages['archived2']), ArchiveDate2, article_date(ArchiveDate2)});
        end
    else
        Archived = ""
    end

    ---------------------------------------------------------------
    -- Data originale se presente (in ordine di preferenza dopo
    -- la data di pubblicazione, quindi l'editore, il luogo di pubblicazione, )
    ---------------------------------------------------------------
    if is_set(OrigDate) then
        if is_set(Date) then
            Date = Date .. " " .. OrigDate
        elseif is_set(PublisherName) then
            PublisherName = PublisherName .. " " .. OrigDate
        elseif is_set(Plase) then
            Place = Place .. " " .. OrigDate
        else
            Date = OrigDate
        end
    end

    -- Several of the above rely upon detecting this as nil, so do it last.
    if is_set(Periodical) then Periodical = wrap( 'italic-title', Periodical ) end
    if config.CitationClass=="news" and is_set(Place) then
        if is_set(Periodical) then
            Periodical = table.concat({Periodical, ' (', Place, ')'})
            Place = ""
        elseif is_set(Title) then
            Title = table.concat({Title, ' (', Place, ')'})
            Place = ""
        end
    end

    ---------------------------------------------------------------
    -- Combino insieme i vari componenti della citazione
    ---------------------------------------------------------------

    local fragment_Title
    if is_set(Title) then
        fragment_Title = Fragment.new({Title, Format, TitleType}, ' '):last(",")
    else
        fragment_Title = Fragment.new({})
        if is_set(Chapter) then
            Chapter = tostring(Fragment.new({Chapter, Format, TitleType}, ' '):last(""))
        end
    end

    local fragment_citation
    if config.CitationClass == "tv" then
        if is_set(Chapter) then
            fragment_Title:last(":"):append(Fragment.new({Issue, Chapter}, sepc))
            Issue = ""
        end
        fragment_citation=Fragment.new({Authors}, sepc)
        fragment_citation:append(fragment_Title)
    else
        if is_set(Authors) and is_set(Editors) and is_set(Title) and not is_set(Chapter) then
            Editors = 'a cura di ' .. Editors
            fragment_citation = Fragment.new({Authors}, sepc)
            fragment_citation:appends({fragment_Title, Editors})
        else
            if is_set(msg_editors) then
                if is_set(Editors) then
                    Editors = wrap(msg_editors, Editors)
                else
                    Authors = wrap(msg_editors, Authors)
                end
            end
            fragment_citation = Fragment.new({Authors, Chapter}, sepc)
            if Chapter ~= "" or Editors ~= "" then
                if A:ORIGIN('Periodical') == 'sito' then -- antepone "su" anzichè "in" per i siti web
                    fragment_citation:last("su")
                else
                    fragment_citation:last("in")
                end
            end
            fragment_citation:appends({Editors, fragment_Title})
        end
    end
    fragment_citation:appends({Conference, Periodical, Others, Series,
                            Volume, Issue, Edition, Place, PublisherName, Station, Date, Position})
    local fragment_ID_list = Fragment.new(ID_list, sepc):append(ID):start(",")
    local fragment_URL = Fragment.new(URL):start(",")
    local fragment_AccessInfo = Fragment.new({AccessDate, Via, Archived}, " "):start(".")
    local fragment_Quote = Fragment.new({Quote}):start(".")
    fragment_citation:appends({fragment_ID_list, fragment_URL, fragment_AccessInfo, fragment_Quote})
    if PostScript == 'nessuno' then
        fragment_citation:last("nothing")
    else
        fragment_citation:last("..")
    end
    fragment_citation:start(" ")
    local text = Language_code .. tostring(fragment_citation)
    --aggiungo l'icona per cita video
    if config.CitationClass == "video" then text = cfg.messages['icon_video'] .. text end
    if config.CitationClass == "audio" then text = cfg.messages['icon_audio'] .. text end

    -- Now enclose the whole thing in a <span/> element
    local options = {};

    if is_set(config.CitationClass) and config.CitationClass ~= "citation" then
        options.class = "citation " .. config.CitationClass;
    else
        options.class = "citation";
    end

--    if string.len(text:gsub("<span[^>/]*>.-</span>", ""):gsub("%b<>","")) <= 2 then
--        z.error_categories = {};
--        text = set_error('empty_citation');
--        z.message_tail = {};
--    end

    if is_set(Ref) then
        text = table.concat({ '<cite id="CITEREF', Ref, --mw.uri.anchorEncode('CITEREF' .. Ref),
                                '" class="', mw.text.nowiki(options.class), '" style="font-style:normal">', text, "</cite>"})
    else
        text = table.concat({ '<cite class="', mw.text.nowiki(options.class), '" style="font-style:normal">', text, "</cite>"})
    end

    local empty_span = '<span style="display:none;">&nbsp;</span>';

    if #z.message_tail ~= 0 then
        text = text .. " ";
        for i,v in ipairs( z.message_tail ) do
            if is_set(v[1]) then
                if i== #z.message_tail then
                    text = text .. error_comment( v[1], v[2] );
                else
                    text = text .. error_comment( v[1] .. "; ", v[2] );
                end
            end
        end
    end

-- Chek to insert category error
    if not is_set(no_tracking_cats) then
        for k, v in pairs( cfg.uncategorized_namespaces ) do
            if this_page.nsText == v then
                no_tracking_cats = "true";
                break;
            end
        end
    end
    no_tracking_cats = no_tracking_cats:lower();
    if in_array(no_tracking_cats, {"", "no", "false", "n"}) then
        for _, v in ipairs( z.error_categories ) do
            text = text .. '[[Categoria:' .. v ..']]';
        end
    end

    return text
end

--[[ ===============================================================================
Funzione di interfaccia per la generazione della citazione, usata dai vari template
cita libro, cita news, ecc...
    ===============================================================================]]
function z.citation(frame)
    local pframe = frame:getParent()

    local args = {};
    local suggestions = {};
    local error_text, error_state;

    local config = {};
    for k, v in pairs( frame.args ) do
        config[k] = v;
        args[k] = v;
    end
    if config['ignore_parent'] == 's' then
        pframe.args = {}
    end
     -- copy unnamed parameter to named parameter
    local lastunnamed = 0
    if cfg.unnamed_parameter[config.CitationClass] then
        for i, v in ipairs(cfg.unnamed_parameter[config.CitationClass]) do
            if pframe.args[i] then
                local args_value = mw.text.trim(pframe.args[i])
                if args_value ~= "" then
                    args[v] = args_value
                end
                lastunnamed = i
            else
                break
            end
        end
    end
    for k, v in pairs( pframe.args ) do
        if v ~= '' then
            if not validate( k ) then
                error_text = "";
                if type( k ) ~= 'string' then
                    -- Exclude empty numbered parameters
                    if v:match("%S+") ~= nil and tonumber(k) > lastunnamed and lastunnamed > 0 then
                        error_text, error_state = set_error( 'text_ignored', {v}, true );
                    end
                elseif validate( k:lower() ) then
                    error_text, error_state = set_error( 'parameter_ignored_suggest', {k, k:lower()}, true );
                else
                    if #suggestions == 0 then
                        suggestions = mw.loadData( 'Modulo:Citazione/Suggerimenti' );
                    end
                    if suggestions[ k:lower() ] ~= nil then
                        error_text, error_state = set_error( 'parameter_ignored_suggest', {k, suggestions[ k:lower() ]}, true );
                    else
                        error_text, error_state = set_error( 'parameter_ignored', {k}, true );
                    end
                end
                if error_text ~= '' then
                    table.insert( z.message_tail, {error_text, error_state} );
                end
            end
            args[k] = v;
        elseif args[k] ~= nil then
            args[k] = v;
        end
    end

    -- hack per l'uso che fanno cita google books e youtube del parametro id
    if args.id and args.id~='' then
        if in_array(config.CitationClass, {"googlebooks", "video"}) then
            args.id = nil
        end
    end
    return citation0( config, args)
end

-- Elenco i formati di documenti gestiti
function z.list_external_links(frame)
    local rows = {'{| class = "wikitable sortable"\n!codice!!collegamento!!visualizzato come'}
    local keys = {}
    for key, _ in pairs(cfg.external_link_type) do
        keys[#keys+1] = key
    end
    table.sort(keys)
    for _,key in ipairs(keys) do
        rows[#rows+1] = '|-\n|' .. key .. '|| [[' .. cfg.external_link_type[key].link ..
                        ']] || (<span style="font-weight: bolder; font-size: smaller;">' ..
                        cfg.external_link_type[key].label .. '</span>)'
    end
    rows[#rows+1] = "|}"
    return table.concat(rows, '\n')
end

return z;
end
