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


const express = require('express')
const fs = require('fs')
const router = express.Router()

//#region Config variables
//var adminPassword = randomFromZeroToNine() + randomFromZeroToNine() + randomFromZeroToNine() + randomFromZeroToNine() //Generate 4 random numbers
var mongoDatabaseConnectionUrl = ""

// Get data from config
var cfg = fs.readFileSync("./config.json")
cfg = JSON.parse(cfg)
//adminPassword = cfg.adminPassword
mongoDatabaseConnectionUrl = cfg.mongoDatabaseConnectionUrl
apiPort = cfg.apiPort
//#endregion

//#region db settings
const low = require('lowdb')
const FileSync = require('lowdb/adapters/FileSync') 
const { json } = require('body-parser')
const logsAdapter = new FileSync(`rooms-logs.json`)
const logsDb = low(logsAdapter)
//#endregion

// *****************************
// *   API starts from there   *
// *****************************

logsDb.defaults({ logs: [] }).write() //default variables for database

// *****************************
// *     Connect to mongodb    *
// *****************************

const MongoClient = require('mongodb').MongoClient
let db

MongoClient.connect(mongoDatabaseConnectionUrl, {useNewUrlParser:true, useUnifiedTopology: true}, async (err, client) => {
    if(err) return console.log("Error while connecting to mongodb! " + err)

    db = client.db("tracky")
    let rooms = db.collection("rooms")

    console.log("Connected to mongodb")


    // *****************************
    // *          Rooms            *
    // *****************************

    router.get("/all", async (req, res) => {
        logsDb.read()

        var clientHardwareID = req.query.hardwareID

        // Check for expired rooms and players
        await RemoveExpiredRoomsAndPlayers()

        var roomsWithExpireTime = []

        await rooms.find({}).forEach(room => {
            var teamsWithoutProtectedData = [];
            room.teams.forEach((team) => {
                teamsWithoutProtectedData.push({
                    "id": team.id,
                    "name": team.name,
                    "color": team.color,
                    "players": team.players.map(p => ({"name": p.name})) ?? [],
                    "passwordRequired": team.passwordRequired,
                    "showForEveryone": team.showForEveryone,
                    "canSeeEveryone": team.canSeeEveryone
                })
            })

            roomsWithExpireTime.push({
                "id": room.id,
                "expiresAt": room.expiresAt,
                "name": room.name,
                "showEnemyTeam": room.showEnemyTeam,
                "isOwner": (room.ownerHardwareID == clientHardwareID && clientHardwareID != undefined).toString(),
                "expiresIn": ExpiresInHours(room.expiresAt),
                "teams": teamsWithoutProtectedData
            })
        });

        res.status(200).send({
            success: "true",
            message: "OK",
            rooms: roomsWithExpireTime
        })
    })

    // Create room
    router.post("/create", async (req, res) => {
        logsDb.read()

        // Check for expired rooms and players
        await RemoveExpiredRoomsAndPlayers()
        var roomsCount = await rooms.countDocuments();

        if(roomsCount > 0) var lastRoomId = (await rooms.find({}).toArray())[roomsCount - 1].id;
        else var lastRoomId = 0

        // When to expire
        var expires = Date.now();
        expires = expires + (86400000 * 2)// add 48h in ms

        var expiresIn = ExpiresInHours(expires)

        try{
            await rooms.insertOne({
                "id": lastRoomId + 1,
                "name": req.body.roomName,
                "expiresAt": expires,
                "showEnemyTeam": req.body.showEnemyTeam,
                "ownerHardwareID": req.body.ownerHardwareID,
                "teams": JSON.parse(req.body.teams)
            })

            // log successful room create action
            logsDb.get("logs").push({
                "action": "create room",
                "time": new Date().toLocaleString("pl"),
                "roomID": lastRoomId + 1,
                "roomName": req.body.roomName,
                "ownerHardwareID": req.body.ownerHardwareID,
                "teams": JSON.parse(req.body.teams)
            }).write()

            return res.status(200).send({
                success: "true",
                message: "Created room with id " + (lastRoomId + 1),
                newRoomId: lastRoomId + 1,
                expiresIn: expiresIn
            })
        }
        catch(e){
            return res.status(500).send({
                success: "false",
                message: "Error while creating room! " + e
            })
        }
    })

    // Update room
    router.patch("/update", async (req, res) => {
        logsDb.read()

        // Check for expired rooms and players
        await RemoveExpiredRoomsAndPlayers()

        const id = parseInt(req.body.roomID, 10);
        
        var list = await rooms.find({}).toArray()
        var roomId = list.findIndex(room => room.id === id);

        // Verify hardwareID
        var ownerHardwareID = list[roomId].ownerHardwareID
        if(ownerHardwareID == req.body.hardwareID){
            var oldTeams = list[roomId].teams
            var teamsWithCorrectPasswords = JSON.parse(req.body.teams);
            teamsWithCorrectPasswords.forEach((team) => {
                if(team.passwordRequired == "true" && team.teamPassword == ""){
                    var oldTeamIndex = oldTeams.findIndex(t => t.id == team.id)
                    if(oldTeamIndex > -1){
                        team.teamPassword = oldTeams[oldTeamIndex].teamPassword
                    }
                    else{
                        console.log("Old team index not found!")
                    }
                }
            })

            try{
                await rooms.updateOne({id: id}, {$set: {"name": req.body.roomName, "showEnemyTeam": req.body.showEnemyTeam, "teams": teamsWithCorrectPasswords}})

                // log successful room update action
                logsDb.get("logs").push({
                    "action": "update room",
                    "time": new Date().toLocaleString("pl"),
                    "roomName": req.body.roomName,
                    "ownerHardwareID": req.body.hardwareID,
                    "teams": teamsWithCorrectPasswords
                }).write()
                
                return res.status(200).send({
                    success: "true",
                    message: "Updated room with id "+ req.body.roomID
                })
            }
            catch(e){
                return res.status(500).send({
                    success: "false",
                    message: "Error while updating room! " + e
                })
            }
        }else{
            return res.status(403).send({
                success: "false",
                message: "Your hardware ID is not equals to room owner hardware ID! Operation unauthorized."
            })
        }    
    })

    // Get room data
    router.get('/:id', async (req, res) => {
        logsDb.read()

        const id = parseInt(req.params.id, 10);
        
        var list = await rooms.find({}).toArray()
        var roomId = list.findIndex(room => room.id === id);

        if(roomId != -1){
            var room = list[roomId]

            var teamsWithoutProtectedData = [];
            room.teams.forEach((team) => {
                teamsWithoutProtectedData.push({
                    "id": team.id,
                    "name": team.name,
                    "color": team.color,
                    "players": team.players.map(p => ({"name": p.name})) ?? [],
                    "passwordRequired": team.passwordRequired,
                    "showForEveryone": team.showForEveryone,
                    "canSeeEveryone": team.canSeeEveryone
                })
            })

            return res.status(200).send({
                success: 'true',
                message: 'Room found',
                expiresIn: ExpiresInHours(room.expiresAt),
                roomId: room.id,
                teams: teamsWithoutProtectedData,
                textMarkers: room.textMarkers ?? [],
                namedPolygons: room.namedPolygons ?? [],
            });
        }
        else{
            return res.status(404).send({
                success: 'false',
                message: 'Room not found. Wrong ID',
            });
        }
    })

    // Refresh room expiry time
    router.post('/refresh/:id', async (req, res) => {
        logsDb.read()

        const id = parseInt(req.params.id, 10);
        
        var list = await rooms.find({}).toArray()
        var roomId = list.findIndex(room => room.id === id);

        if(roomId != -1){
            var room = list[roomId]

            // When to expire
            var expires = Date.now();
            expires = expires + (86400000 * 2)// add 48h in ms
            
            try{
                await rooms.updateOne({id: id}, {$set: {"expiresAt": expires}})

                var expiresIn = ExpiresInHours(expires)
        
                // log successful room expiry time update action
                logsDb.get("logs").push({
                    "action": "update expiry time",
                    "time": new Date().toLocaleString("pl"),
                    "roomName": room.name,
                }).write()

                return res.status(200).send({
                    success: 'true',
                    message: 'Room expiry time refreshed',
                    expiresIn: expiresIn,
                    roomId: room.id,
                    teams: room.teams
                });
            }
            catch(e){
                return res.status(500).send({
                    success: 'false',
                    message: 'Internal error while updating expiry time! ' + e,
                });
            }
        }
        else{
            return res.status(404).send({
                success: 'false',
                message: 'Room not found. Wrong ID',
            });
        }
    })

    // Remove room
    router.delete('/:id', async (req, res) => {
        logsDb.read()

        const id = parseInt(req.params.id, 10);

        // Verify hardware ID
        var list = await rooms.find({}).toArray()
        var roomId = list.findIndex(room => room.id === id);
        if(roomId == -1){
            return res.status(404).send({
                success: 'false',
                message: 'Room not found'
            });
        }
        var ownerHardwareID = list[roomId].ownerHardwareID
        if(ownerHardwareID == req.query.hardwareID){
            if(await RemoveRoom(id)){
                // log successful room delete action
                logsDb.get("logs").push({
                    "action": "delete room",
                    "time": new Date().toLocaleString("pl"),
                    "roomID": id,
                    "ownerHardwareID": req.query.hardwareID,
                }).write()

                return res.status(200).send({
                    success: 'true',
                    message: 'Room found and deleted'
                });
            }
            else{
                return res.status(404).send({
                    success: 'false',
                    message: 'Room not found'
                });
            }
        }
        else{
            return res.status(403).send({
                success: "false",
                message: "Your hardware ID is not equals to room owner hardware ID! Operation unauthorized."
            })
        }
    })

    // *****************************
    // *            Map            *
    // *****************************

    // Edit map
    router.post('/map/:id', async (req, res) => {
        logsDb.read()

        const id = parseInt(req.params.id, 10);
        
        var list = await rooms.find({}).toArray()
        var roomId = list.findIndex(room => room.id === id);

        if(roomId != -1){
            // Verify hardwareID
            var ownerHardwareID = list[roomId].ownerHardwareID
            if(ownerHardwareID == req.body.hardwareID){
                var room = list[roomId]
                var _textMarkers = JSON.parse(req.body.textMarkers);
                var _namedPolygons = JSON.parse(req.body.namedPolygons);
                
                try{
                    await rooms.updateOne({id: id}, {$set: {"textMarkers": _textMarkers, "namedPolygons": _namedPolygons}})

                    // log successful map update action
                    logsDb.get("logs").push({
                        "action": "update map",
                        "time": new Date().toLocaleString("pl"),
                        "roomName": room.name,
                    }).write()

                    return res.status(200).send({
                        success: 'true',
                        message: 'Map updated',
                        roomId: room.id,
                    });
                }
                catch(e){
                    return res.status(500).send({
                        success: 'false',
                        message: 'Internal error while updating map! ' + e,
                    });
                }
            }else{
                return res.status(403).send({
                    success: "false",
                    message: "Your hardware ID is not equals to room owner hardware ID! Operation unauthorized."
                })
            }        
        }
        else{
            return res.status(404).send({
                success: 'false',
                message: 'Room not found. Wrong ID',
            });
        }
    })

    // *****************************
    // *          Players          *
    // *****************************

    // Join player to team on room ID
    router.post('/join/:id', async (req, res) => {
        logsDb.read()

        // Check for expired rooms and players
        await RemoveExpiredRoomsAndPlayers()

        const id = parseInt(req.params.id, 10);
        
        var list = await rooms.find({}).toArray()
        var roomId = list.findIndex(room => room.id === id);
        if(roomId != -1) var teamId = list[roomId].teams.findIndex(team => team.id === req.body.teamId)

        if(roomId != -1 && teamId != -1){
            // Check is name not taken
            var isNameTaken = false
            list[roomId].teams[teamId].players.forEach((player) => {
                if(player.name === req.body.playerName) isNameTaken = true
            })

            // Check password if required
            if(list[roomId].teams[teamId].passwordRequired == "true"){
                if(list[roomId].teams[teamId].teamPassword != req.body.teamPassword){
                    return res.status(401).send({
                        success: 'false',
                        message: 'Wrong team password',
                    });
                }
            }

            if(!isNameTaken){          
                await rooms.updateOne({id: id, "teams.id": list[roomId].teams[teamId].id}, {$push: {"teams.$.players": {
                    "name": req.body.playerName.toString(),
                    "lastSeen": Date.now(),
                    "icon": req.body.icon,
                    "latitude": "0",
                    "longitude": "0"
                }}})

                // log successful join action
                logsDb.get("logs").push({
                    "action": "joined",
                    "time": new Date().toLocaleString("pl"),
                    "nickName": req.body.playerName,
                    "room": list[roomId].id,
                    "team": req.body.teamName
                }).write()

                return res.status(200).send({
                    success: 'true',
                    message: `Player "${req.body.playerName}" joined to team: ${req.body.teamName}`
                });
            }
            else{
                return res.status(409).send({
                    success: 'false',
                    message: `Player with this name already exists in this team`
                });
            }        
        }
        else{
            return res.status(404).send({
                success: 'false',
                message: `Room or team not found`
            });
        }
    })

    // Update player location and Map data on room ID
    router.post('/:id', async (req, res) => {
        const id = parseInt(req.params.id, 10);
        
        var list = await rooms.find({}).toArray()
        var success = false;
        var roomId = list.findIndex(room => room.id === id);
        if(roomId != -1) var teamId = list[roomId].teams.findIndex(team => team.id === req.body.teamId)

        if(roomId != -1 && teamId != -1){
            success = true;

            var playerIndex = list[roomId].teams[teamId].players.findIndex(player => player.name === req.body.playerName)
            var hideMe = req.body.hideMe == "true" ?? false

            if(playerIndex > -1){
                var newPlayerData = list[roomId].teams[teamId].players[playerIndex]                
                newPlayerData.latitude= req.body.latitude
                newPlayerData.longitude= req.body.longitude
                newPlayerData.lastSeen= Date.now()
                newPlayerData.hideMe= hideMe.toString()
                
                await rooms.updateOne({id: id, "teams.id": list[roomId].teams[teamId].id}, {$set: {"teams.$.players.$[player]": newPlayerData}}
                    , {arrayFilters: [{"player.name": list[roomId].teams[teamId].players[playerIndex].name}]})
            }
            else{
                return res.status(404).send({
                    success: 'false',
                    message: 'Player not found in this team',
                });
            }
            
            var room = list[roomId]

            var teamsWithoutProtectedData = [];
            room.teams.forEach((team) => {
                teamsWithoutProtectedData.push({
                    "id": team.id,
                    "name": team.name,
                    "color": team.color,
                    "players": team.players,
                    "passwordRequired": team.passwordRequired,
                    "showForEveryone": team.showForEveryone,
                    "canSeeEveryone": team.canSeeEveryone
                })
            })

            var teamsToReturn = []
            teamsWithoutProtectedData.forEach((t) => {
                let teamToReturn = {...t} // Clone t before clearing
                teamToReturn.players = [] //? Clear players list

                let showTeamForEveryone = t.showForEveryone ?? "false"
                let teamCanSeeEveryone = room.teams[teamId].canSeeEveryone ?? "false"

                if(showTeamForEveryone == "true"){
                    // Return everyone but not hidden players
                    teamToReturn.players = t.players.filter((_p) => _p.hideMe != "true")
                    teamsToReturn.push(teamToReturn)
                    return
                }

                // if player is in team that can see everyone return every team
                if(teamCanSeeEveryone == "true") {
                    // Return everyone but not hidden players
                    teamToReturn.players = t.players.filter((_p) => _p.hideMe != "true")
                    teamsToReturn.push(teamToReturn)
                    return
                }

                // if show enemy team is off, return only players team
                if(room.showEnemyTeam == "false" && t.id != req.body.teamId) return

                t.players.forEach((p) => {
                    // if player is hidden, skip
                    if(p.hideMe == "true") return;
                    teamToReturn.players.push(p)
                })

                teamsToReturn.push(teamToReturn)
            })
            
            return res.status(200).send({
                success: 'true',
                message: 'Room found, updating location and returning players',
                teams: teamsToReturn,
                showEnemyTeam: room.showEnemyTeam,
                textMarkers: room.textMarkers ?? [],
                namedPolygons: room.namedPolygons ?? [],
            });
        }

        if(!success){
            return res.status(404).send({
                success: 'false',
                message: 'Room not found. Wrong ID',
            });
        }
    })

    // Remove player from team on room ID
    router.post('/leave/:id', async (req, res) => {
        logsDb.read();

        const id = parseInt(req.params.id, 10);
        
        var list = await rooms.find({}).toArray()
        var roomId = list.findIndex(room => room.id === id);
        if(roomId != -1) var teamId = list[roomId].teams.findIndex(team => team.id === req.body.teamId)

        if(roomId != -1 && teamId != -1){
            // Check is player with that name in team
            var isInTeam = false
            var playerToRemove;
            list[roomId].teams[teamId].players.forEach((player) => {
                if(player.name === req.body.playerName) {
                    isInTeam = true
                    playerToRemove = player;
                }
            })

            if(isInTeam){
                await RemovePlayerFromTeam(id, roomId, teamId, playerToRemove);

                // log successful leave action
                logsDb.get("logs").push({
                    "action": "leaved",
                    "time": new Date().toLocaleString("pl"),
                    "nickName": req.body.playerName,
                    "room": list[roomId].id,
                    "team": req.body.teamName
                }).write()

                return res.status(200).send({
                    success: 'true',
                    message: `Player "${req.body.playerName}" removed from team: ${req.body.teamName}`
                });
            }
            else{
                return res.status(409).send({
                    success: 'false',
                    message: `Player with this name not found in this team`
                });
            }        
        }
        else{
            return res.status(404).send({
                success: 'false',
                message: `Room or team not found`
            });
        }
    })

    // *****************************
    // *      Import / Export      *
    // *****************************

    // Export room data
    router.get('/export/:id', async (req, res) => {
        logsDb.read()

        const id = parseInt(req.params.id, 10);
        
        var list = await rooms.find({}).toArray()
        var roomId = list.findIndex(room => room.id === id);

        if(roomId != -1){
            var room = list[roomId]

            // Clear all players before sending
            room.teams.forEach((r)=>{
                r.players = []
            })

            // log successful room export action
            logsDb.get("logs").push({
                "action": "export room",
                "time": new Date().toLocaleString("pl"),
                "roomID": room.id,
                "roomName": room.name,
            }).write()

            return res.status(200).send({
                success: 'true',
                message: 'Room found',
                room: {
                    name: room.name,
                    showEnemyTeam: room.showEnemyTeam,
                    teams: room.teams,
                    textMarkers: room.textMarkers ?? [],
                    namedPolygons: room.namedPolygons ?? [],
                }
            });
        }
        else{
            return res.status(404).send({
                success: 'false',
                message: 'Room not found. Wrong ID',
            });
        }
    })

    // Import room
    router.post('/import/new', async (req, res) => {
        logsDb.read();

        // Check for expired rooms and players
        await RemoveExpiredRoomsAndPlayers()

        var list = await rooms.find({}).toArray()
        var roomsCount = list.length;

        if(roomsCount > 0) var lastRoomId = list[roomsCount - 1].id;
        else var lastRoomId = 0

        // When to expire
        var expires = Date.now();
        expires = expires + (86400000 * 2)// add 48h in ms

        var expiresIn = ExpiresInHours(expires)
        try{
            try{
                await rooms.insertOne({
                    "id": lastRoomId + 1,
                    "name": req.body.room.name,
                    "expiresAt": expires,
                    "showEnemyTeam": req.body.room.showEnemyTeam,
                    "ownerHardwareID": req.body.ownerHardwareID,
                    "teams": req.body.room.teams,
                    "textMarkers": req.body.room.textMarkers,
                    "namedPolygons": req.body.room.namedPolygons
                })

                // log successful room create action
                logsDb.get("logs").push({
                    "action": "create room from file (import room)",
                    "time": new Date().toLocaleString("pl"),
                    "roomID": lastRoomId + 1,
                    "roomName": req.body.room.name,
                    "ownerHardwareID": req.body.ownerHardwareID,
                    "teams": req.body.room.teams
                }).write()
        
                return res.status(200).send({
                    success: "true",
                    message: "Created room with id " + (lastRoomId + 1),
                    newRoomId: lastRoomId + 1,
                    newRoomName: req.body.room.name,
                    expiresIn: expiresIn
                })
            }
            catch(e){
                return res.status(500).send({
                    success: "false",
                    message: "Error while creating room! " + e
                })
            }
        }
        catch(e){
            return res.status(500).send({
                success: "false",
                message: "Error while creating room. File was in wrong format"
            })
        }
    })

    function ExpiresInHours(time){
        return ((time - Date.now()) / 1000 / 60 / 60).toPrecision(2)
    }

    async function RemoveRoom(roomId){        
        var list = await rooms.find({}).toArray()
        var roomIndexToRemove = list.findIndex(room => room.id === roomId);
        
        if(roomIndexToRemove > -1){
            await rooms.deleteOne({_id: list[roomIndexToRemove]._id})
            return true
        }
        else{
            return false
        }
    }

    async function RemovePlayerFromTeam(id, roomId, teamId, player){
        var list = await rooms.find({}).toArray()
        await rooms.updateOne({id: id, "teams.id": list[roomId].teams[teamId].id}, {$pull: {"teams.$.players": player}})
    }

    async function RemoveExpiredRoomsAndPlayers(){
        var list = await rooms.find({}).toArray()
        var roomsToRemove = []
        var playersToRemove = []

        list.forEach( room => {
            try{
                if(room.expiresAt < Date.now()) roomsToRemove.push(room)
            }
            catch(e){
                console.log(e)
            }

            try{
                // Look for expired players
                room.teams.forEach(team => {
                    team.players.forEach(player => {
                        if((Date.now() - player.lastSeen) > 1000 * 60 * 5) playersToRemove.push({"player": player, "team": team, "room": room})
                    })
                })
            }
            catch(e){
                console.log(e)
            }
        });

        if(roomsToRemove.length > 0){
            for (const room of roomsToRemove){
                await rooms.deleteOne({id: room.id})
            }
        }
        
        if(playersToRemove.length > 0){
            for(const obj of playersToRemove){
                var roomIndex = list.findIndex(room => room.id === obj.room.id);
                
                if(roomIndex > -1){
                    var teamId = list[roomIndex].teams.findIndex(team => team.name === obj.team.name)

                    if(teamId > -1){
                        await RemovePlayerFromTeam(obj.room.id, roomIndex, teamId, obj.player)
                    }           
                }
            }
        }
    }

})
module.exports = router