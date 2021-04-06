/*

MIT License

Copyright (c) 2021 Kacper Marcinkiewicz

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/


const websocket = require('ws')
const https = require('https');
const { IncomingMessage } = require('http'); // For intellisense
const fs = require('fs')


//#region Config variables
var databaseName = "questions"

// Get data from config
var cfg = fs.readFileSync("./config.json")
cfg = JSON.parse(cfg)
var databaseName = cfg.databaseName
//#endregion

//#region db settings
const low = require('lowdb')
const FileSync = require('lowdb/adapters/FileSync') 
const logsAdapter = new FileSync(`${databaseName}-logs.json`)
const logsDb = low(logsAdapter)
//#endregion

class Room {
    constructor({id = -1,players = []}){
        this.id = id;
        this.players = players;
    }
}

//! THIS CODE IS NOT CLUSTER READY! 

/** {credentials} = {} - because without this calling function without credentials like ```chat(5001)``` can throw error */
module.exports = (port, {credentials} = {}) => {
    String.prototype.isNullOrEmpty = function() {
        var str = this.toString()
        return (!str || 0 === str.length);
    }
    String.prototype.isNotNullOrEmpty = function() {
        var str = this.toString()
        return !(!str || 0 === str.length);
    }

    /**
     * @type {Room[]}
     */
    var rooms = []

    /**
     * @type {websocket.Server}
     */
    var wss;

    if(credentials == null){
        StartServer(port)
    }
    else{
        StartHttpsServer(port, credentials)
    }

    
    // *****************************
    // *         Functions         *
    // *****************************

    function StartServer(port){
        wss = new websocket.Server({port: port})
        wss.on('connection', onConnection)
        wss.on('close', onCloseServer)
        wss.on('error', (error) => log("Error: " + error))
        log("Started on port " + port)
        console.log("[Chat] - Started on port " + port)
    }
    
    function StartHttpsServer(port, credentials){
        var httpsServer = https.createServer(credentials);
        httpsServer.listen(port);
        
        wss = new websocket.Server({server: httpsServer})
        wss.on('connection', onConnection)
        wss.on('close', onCloseServer)
        wss.on('error', (error) => log("Error: " + error))
        log("Started on port " + port + " with HTTPS support")
        console.log("[Chat] - Started on port " + port + " with HTTPS support")
    }

    /** 
     * @param {websocket} ws 
     * @param {IncomingMessage} req 
     */
    function onConnection(ws, req){
        try{
            ws.id = req.headers['sec-websocket-key']
            ws.player = {
                status: "not connected",
                nickname: null,
                roomId: null,
                id: ws.id
            }

            ws.isAlive = true;
            ws.on('pong', heartbeat);
    
            log("Connected client with id (" + ws.id + ")")
    
            ws.on('message', (message) => {
                try{
                    // wss.clients.forEach((client) => {
                    //     if(client != ws && client.readyState == websocket.OPEN){
                    //         client.send(ws.id + ": " + message)
                    //     }
                    // })
                    if(message == "status"){
                        ws.send(JSON.stringify({success: true, messageType: "response", player: ws.player}))
                    }

                    //? JOIN: {"action":"join", "data":{"roomId": 4, "nickname": "player", "message":"Hello", "teamId": "05321b0c-053a-449d-8136-ada8923aaa24", "destination":"global", "teamName": "No pass","teamColor": "ff4caf50"}}

                    if(isJson(message)){
                        var json = JSON.parse(message);
                        var action = json.action?.toString().toLowerCase() ?? null
                        
                        if(action == null) return

                        if(action == "message"){
                            if(!json.data) return;
                            if(ws.player.roomId == null) return ws.send(JSON.stringify({success: false, messageType: "response", message: "You are not in room"}))
                            if(ws.player.nickname.toString().isNullOrEmpty()) return ws.send(JSON.stringify({success: false, messageType: "response", message: "You can't send message without nickname"}))
                            if(!json.data.message?.toString().isNotNullOrEmpty()) return ws.send(JSON.stringify({success: false, messageType: "response", message: "Message cannot be empty"}))
                            if(!json.data.destination?.toString().isNotNullOrEmpty()) return ws.send(JSON.stringify({success: false, messageType: "response", message: "Destination cannot be empty"}))
                            
                            var isMsgGlobal = json.data.destination?.toString() == "global";
                            wss.clients.forEach((client) => {
                                if(client != ws && client.readyState == websocket.OPEN && client.player.roomId == ws.player.roomId){
                                    if((isMsgGlobal) || (json.data.destination?.toString() == client.player.teamId)) { 
                                        client.send(JSON.stringify({
                                            success: true, 
                                            messageType: "message", 
                                            nickname: ws.player.nickname, 
                                            isGlobal: isMsgGlobal,
                                            message: json.data.message,
                                            teamName: ws.player.teamName,
                                            teamColor: ws.player.teamColor,
                                        })) 
                                    }
                                }
                            })
                        }
    
                        if(action == "join"){
                            if(json.data == null) return;
                            if(json.data.roomId != null && json.data.nickname != null && json.data.teamId && json.data.teamName && json.data.teamColor){
                                if(ws.player.roomId != null) removePlayerFromRoom(ws)
    
                                ws.player.status = "connected"
                                ws.player.nickname = json.data.nickname
                                ws.player.roomId = json.data.roomId
                                ws.player.teamId = json.data.teamId
                                ws.player.teamName = json.data.teamName
                                ws.player.teamColor = json.data.teamColor
    
                                var roomIndex = rooms.findIndex((r) => r.id == json.data.roomId)
    
                                if(roomIndex == -1){
                                    rooms.push(new Room({id: json.data.roomId, players: [{...ws.player}]}))
                                    ws.send(JSON.stringify({success: true, messageType: "response", message: "Room created, player added"}))
                                }
                                else{
                                    rooms[roomIndex].players.push({...ws.player})
                                    ws.send(JSON.stringify({success: true, messageType: "response", message: "Player added"}))
                                }
                            }
                        }

                        if(action == "leave"){
                            if(json.data == null) return;
                            if(ws.player.roomId != null) {
                                if(removePlayerFromRoom(ws)){
                                    ws.send(JSON.stringify({success: true, messageType: "response", message: "Room leaved"}))
                                }
                                else{
                                    ws.send(JSON.stringify({success: false, messageType: "response", message: "Error while leaving room. Player data has been reset"}))
                                }
                            }
                        }
    
                        if(action == "status"){
                            ws.send(JSON.stringify({success: true, messageType: "response", player: ws.player}))
                        }
    
                        if(action == "rooms"){
                            ws.send(JSON.stringify({success: true, messageType: "response", rooms: rooms}))
                        }
                    }
                }
                catch(e){
                    log("Error in onMessage: " + e)
                }
            })

            ws.on('error', (wsErr) => log("WS Error: " + wsErr))
    
            ws.on('close', (code, reason) => {
                if(ws.player.roomId != null){
                    var removed = removePlayerFromRoom(ws)
                    log("Disconnected" + (removed ? " (and removed from room) " : " ") + "client with id (" + ws.id + "). Code: " + code + ". Reason: " + reason)
                }
                else log("Disconnected client with id (" + ws.id + "). Code: " + code + ". Reason: " + reason)
            })
        }catch(er){
            log("Error: " + er)
        }
    }

    function onCloseServer(){   
        clearInterval(interval);
    }
    
    //#region Keep alive interval
    const interval = setInterval(function ping() {
        wss.clients.forEach(function each(ws) {        
          if (ws.isAlive === false) {
            log("Disconnected client with id (" + ws.id + ") after isAlive == false")
            return ws.terminate();
          }
      
          ws.isAlive = false;
          ws.ping(noop);
        });
    }, 30000);

    function noop() {}

    function heartbeat() {
      this.isAlive = true;
    }
    //#endregion

    /**
     * @param {websocket} ws client's websocket 
     */
    function removePlayerFromRoom(ws){
        var roomIndex = rooms.findIndex(r => r.id == ws.player.roomId)
        if(roomIndex == -1) {
            log("Error while removing player from room, room with id " + ws.player.roomId + " not found")
            resetPlayerData(ws)
            return false
        }

        var indexOfPlayer = rooms[roomIndex].players.findIndex((p) => p.id == ws.id)
        if(indexOfPlayer == -1) {
            log("Error while removing player from room, player not found in room with id " + ws.player.roomId)
            resetPlayerData(ws)
            return false
        } 

        rooms[roomIndex].players.splice(indexOfPlayer,1)
        resetPlayerData(ws)

        // if room is empty delete it
        if(rooms[roomIndex].players.length <= 0) rooms.splice(roomIndex,1)
        return true
    }

    /**
     * @param {websocket} ws client's websocket 
     */
    function resetPlayerData(ws){
        ws.player.status = "not connected"
        ws.player.nickname = null
        ws.player.roomId = null
        ws.player.teamId = null
        ws.player.teamName = null
        ws.player.teamColor = null
    }

    function log(message){
        logsDb.read()
        // log chat action
        logsDb.get("logs").push({
            "action": "Chat action",
            "time": new Date().toLocaleString("pl"),
            "message": message,
        }).write()
    }

    function isJson(str) {
        try {
            JSON.parse(str);
        } catch (e) {
            return false;
        }
        return true;
    }
}