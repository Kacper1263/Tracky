const websocket = require('ws')
const https = require('https');
const { IncomingMessage } = require('http'); // For intellisense

class Room {
    constructor({id = -1,players = []}){
        this.id = id;
        this.players = players;
    }
}

module.exports = (port, {credentials} = {}) => {
    console.chatLog = function(message){
        console.log("[Chat] - " + message) // TODO: In production change this to logsDb instead of console log
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
        wss.on('error', (error) => console.chatLog("Error: " + error))
        console.chatLog("Started on port " + port)
    }
    
    function StartHttpsServer(port, credentials){
        var httpsServer = https.createServer(credentials);
        httpsServer.listen(port);
        
        wss = new websocket.Server({server: httpsServer})
        wss.on('connection', onConnection)
        wss.on('close', onCloseServer)
        wss.on('error', (error) => console.chatLog("Error: " + error))
        console.chatLog("Started on port " + port + " with HTTPS support")
    }

    /** 
     * 
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
    
            console.chatLog("Connected client with id (" + ws.id + ")")
    
            ws.on('message', (message) => {
                // wss.clients.forEach((client) => {
                //     if(client != ws && client.readyState == websocket.OPEN){
                //         client.send(ws.id + ": " + message)
                //     }
                // })
                if(isJson(message)){
                    var json = JSON.parse(message);
                    var action = json.action?.toString().toLowerCase() ?? null
                    
                    if(action == null) return

                    if(action == "join"){
                        if(json.data == null) return;
                        if(json.data.roomId != null && json.data.nickname != null){
                            if(ws.player.roomId != null) removePlayerFromRoom(ws)

                            ws.player.status = "connected"
                            ws.player.nickname = json.data.nickname
                            ws.player.roomId = json.data.roomId

                            var roomIndex = rooms.findIndex((r) => r.id == json.data.roomId)

                            if(roomIndex == -1){
                                rooms.push(new Room({id: json.data.roomId, players: [{...ws.player}]}))
                                ws.send(JSON.stringify({success: true, message: "Room created, player added"}))
                            }
                            else{
                                rooms[roomIndex].players.push({...ws.player})
                                ws.send(JSON.stringify({success: true, message: "Player added"}))
                            }
                        }
                    }

                    if(action == "status"){
                        ws.send(JSON.stringify({success: true, player: ws.player}))
                    }

                    if(action == "rooms"){
                        ws.send(JSON.stringify({success: true, rooms: rooms}))
                    }
                }
            })

            ws.on('error', (wsErr) => console.chatLog("WS Error: " + wsErr))
    
            ws.on('close', (code, reason) => {
                if(ws.player.roomId != null){
                    var removed = removePlayerFromRoom(ws)
                    console.chatLog("Disconnected" + (removed ? " (and removed from room) " : " ") + "client with id (" + ws.id + "). Code: " + code + ". Reason: " + reason)
                }
                else console.chatLog("Disconnected client with id (" + ws.id + "). Code: " + code + ". Reason: " + reason)
            })
        }catch(er){
            console.chatLog("Error: " + er)
        }
    }

    /** 
     * 
     * @param {websocket} ws 
     * @param {IncomingMessage} req 
     */
    function onCloseServer(ws, req){   
        clearInterval(interval);
    }
    
    // Keep alive interval
    const interval = setInterval(function ping() {
        wss.clients.forEach(function each(ws) {        
          if (ws.isAlive === false) {
            console.chatLog("Disconnected client with id (" + ws.id + ") after isAlive == false")
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

    function removePlayerFromRoom(ws){
        var roomIndex = rooms.findIndex(r => r.id == ws.player.roomId)
        if(roomIndex == -1) {
            console.chatLog("Error while removing player from room, room with id " + ws.player.roomId + " not found")
            return false
        }

        var indexOfPlayer = rooms[roomIndex].players.findIndex((p) => p.id == ws.id)
        if(indexOfPlayer == -1) {
            console.chatLog("Error while removing player from room, player not found in room with id " + ws.player.roomId)
            return false
        } 

        rooms[roomIndex].players.splice(indexOfPlayer,1)
        return true
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