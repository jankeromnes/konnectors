americano = require 'americano-cozy'
requestJson = require 'request-json'
request = require 'request'
moment = require 'moment'
cheerio = require 'cheerio'
fs = require 'fs'
async = require 'async'

fetcher = require '../lib/fetcher'
localization = require '../lib/localization_manager'


log = require('printit')
    prefix: "Blockchain"
    date: true


# Models

# TODO date usage:
# - minimal (only keep your transactions)
# - big (record all transactions from now on, ~1GB / year)
# TODO stay in sync with the blockchain

BlockchainAddress = americano.getModel 'BlockchainAddress',
    address: String
    transactions: (x) -> x #list of BlockchainTransaction?

BlockchainTransaction = americano.getModel 'BlockchainTransaction',
    tx_index: Number
    time: Date
    ver: Number
    inputs: (x) -> x #list of BlockchainTransactionInput?
    out: (x) -> x #list of BlockchainTransactionOutput?
    #vin_sz: Number
    #vout_sz: Number
    #hash: String
    #block_height: Number
    #relayed_by: String
    #lock_time: Number
    #result: Number
    #size: Number
    #double_spend: Boolean

BlockchainTransactionInput = americano.getModel 'BlockchainTransactionInput'
    script: String
    prev_out: String #BlockchainTransactionOutput.script
    #sequence: Number

BlockchainTransactionOutput = americano.getModel 'BlockchainTransactionOutput'
    script: String
    tx_index: Number
    addr: String
    value: Number
    #n: Number
    #type: Number

BlockchainAddress.all = (params, callback) ->
    BlockchainAddress.request 'byDate', params, callback # FIXME 'byDate'? no `date`

BlockchainTransaction.all = (params, callback) ->
    BlockchainTransaction.request 'byDate', params, callback # FIXME 'byDate'? no `date` (but `time`)

BlockchainTransactionInput.all = (params, callback) ->
    BlockchainTransactionInput.request 'byDate', params, callback # FIXME 'byDate'? no `date`

BlockchainTransactionOutput.all = (params, callback) ->
    BlockchainTransactionOutput.request 'byDate', params, callback # FIXME 'byDate'? no `date`

# Konnector

module.exports =

    name: "Blockchain"
    slug: "blockchain"
    description: 'konnector description blockchain'
    vendorLink: "https://blockchain.info"

    fields:
        addresses: "addresses"
    models:
        blockchainaddress: BlockchainAddress
        blockchaintransaction: BlockchainTransaction
        blockchaintransactioninput: BlockchainTransactionInput
        blockchaintransactionoutput: BlockchainTransactionOutput

    # Define model requests.
    init: (callback) ->
        map = (doc) -> emit doc.date, doc
        async.series [
            (done) -> BlockchainAddress.defineRequest 'byDate', map, done
            (done) -> BlockchainTransaction.defineRequest 'byDate', map, done
            (done) -> BlockchainTransactionInput.defineRequest 'byDate', map, done
            (done) -> BlockchainTransactionOutput.defineRequest 'byDate', map, done
        ], callback

    fetch: (requiredFields, callback) ->
        log.info 'import started'

        client = requestJson.newClient 'https://blockchain.info'
        addresses = requiredFields.addresses.split '|'
        
        async.eachSeries addresses, (address, callback) ->
            path = "address/#{address}?format=json"
            client.get path, (err, res, json) ->
                if err
                    callback err
                    return
                // process: json.txs
            
            async.eachSeries json.addresses, (page, callback) -> 
                // address
            for transaction in json.txs
                // transaction
                        saveMeasures measures.body.measuregrps, callback

        
        log.info "Import started"
        
        fetcher.new()
            .use(getAddresses)
            .use(buildKnownIDs)
            .use(importStuff)
            .fetch (err, fields, stuff, data) ->
                log.info "Import finished"
                notifContent = null
                # TODO notifContent about what was imported
                callback err, notifContent

# Get blockchain addresses and associated transactions.
getAddresses = (requiredFields, entries, data, next) ->
    client = requestJson.newClient 'https://blockchain.info'
    addresses = requiredFields.addresses
    
    path = "multiaddr?active=#{addresses}"

    data.addresses = []
    data.transactions = []
    
    log.info "Fetch blockchain addresses..."
    client.get path, (err, res, json) ->
        return log.error err if err
        for address in json.addresses
            data.addresses.push address
        for transaction in json.txs
            data.transactions.push transaction

# Build IDs of known addresses and transactions.
buildKnownIDs = (requiredFields, entries, data, next) ->
    entries.addressID = {}
    entries.transactionIDs = {}
    BlockchainAddress.all limit: 9999, (err, addresses) -> # FIXME no limit?
        if err
            log.error err
            next err
        else
            for address in addresses
                entries.addressIDs[address.address] = true
            next()
    BlockchainTransaction.all limit: 9999, (err, transactions) -> # FIXME no limit?
        if err
            log.error err
            next err
        else
            for transaction in transactions
                entries.transactionIDs[transaction.tx_index] = true
            next()
        # FIXME next() once for all