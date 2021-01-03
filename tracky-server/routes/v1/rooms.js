/*

MIT License

Copyright (c) 2020 Kacper Marcinkiewicz

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
var databaseName = "questions"

// Get data from config
var cfg = fs.readFileSync("./config.json")
cfg = JSON.parse(cfg)
//adminPassword = cfg.adminPassword
databaseName = cfg.databaseName
apiPort = cfg.apiPort
//#endregion

//#region db settings
const low = require('lowdb')
const FileSync = require('lowdb/adapters/FileSync') 
const { json } = require('body-parser')
const adapter = new FileSync(`${databaseName}.json`)
const logsAdapter = new FileSync(`${databaseName}-logs.json`)
const db = low(adapter)
const logsDb = low(logsAdapter)
//#endregion

// *****************************
// *   API starts from there   *
// *****************************

db.defaults({ rooms: [] }).write() //default variables for database
logsDb.defaults({ logs: [] }).write() //default variables for database


// *****************************
// *          Rooms            *
// *****************************

router.get("/all", (req, res) => {
    db.read()
    var clientHardwareID = req.query.hardwareID

    // Check for expired rooms and players
    RemoveExpiredRoomsAndPlayers()

    var roomsWithExpireTime = []

    db.get("rooms").value().forEach(room => {
        roomsWithExpireTime.push({
            "id": room.id,
            "expiresAt": room.expiresAt,
            "name": room.name,
            "showEnemyTeam": room.showEnemyTeam,
            "isOwner": (room.ownerHardwareID == clientHardwareID && clientHardwareID != undefined).toString(),
            "expiresIn": ExpiresInHours(room.expiresAt),
            "teams": room.teams
        })
    });

    res.status(200).send({
        success: "true",
        message: "OK",
        rooms: roomsWithExpireTime
    })
})

// Create room
router.post("/create", (req, res) => {
    db.read();

    // Check for expired rooms and players
    RemoveExpiredRoomsAndPlayers()

    var rooms = db.get("rooms").value()
    var roomsCount = rooms.length;

    if(roomsCount > 0) var lastRoomId = rooms[roomsCount - 1].id;
    else var lastRoomId = 0

    // When to expire
    var expires = Date.now();
    expires = expires + (86400000 * 2)// add 48h in ms

    var expiresIn = ExpiresInHours(expires)

    if(db.get("rooms").push({
        "id": lastRoomId + 1,
        "name": req.body.roomName,
        "expiresAt": expires,
        "showEnemyTeam": req.body.showEnemyTeam,
        "ownerHardwareID": req.body.ownerHardwareID,
        "teams": JSON.parse(req.body.teams)
    }).write()){
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
    else{
        return res.status(500).send({
            success: "false",
            message: "Error while creating room"
        })
    }
})

// Update room
router.patch("/update", (req, res) => {
    db.read();

    // Check for expired rooms and players
    RemoveExpiredRoomsAndPlayers()

    const id = parseInt(req.body.roomID, 10);
    
    var list = db.get("rooms").value();
    var roomId = list.findIndex(room => room.id === id);

    // Verify hardwareID
    var ownerHardwareID = db.get("rooms").get(roomId).get("ownerHardwareID").value()
    if(ownerHardwareID == req.body.hardwareID){
        if(db.get("rooms").get(roomId).set("name", req.body.roomName).set("showEnemyTeam", req.body.showEnemyTeam).set("teams", JSON.parse(req.body.teams)).write()){
            // log successful room update action
            logsDb.get("logs").push({
                "action": "update room",
                "time": new Date().toLocaleString("pl"),
                "roomName": req.body.roomName,
                "ownerHardwareID": req.body.hardwareID,
                "teams": JSON.parse(req.body.teams)
            }).write()
            
            return res.status(200).send({
                success: "true",
                message: "Updated room with id "+ req.body.roomID
            })
        }
        else{
            return res.status(500).send({
                success: "false",
                message: "Error while updating room"
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
router.get('/:id', (req, res) => {
    db.read()

    const id = parseInt(req.params.id, 10);
    
    var list = db.get("rooms").value();
    var roomId = list.findIndex(room => room.id === id);

    if(roomId != -1){
        var room = db.get("rooms").get(roomId).value();

        return res.status(200).send({
            success: 'true',
            message: 'Room found',
            expiresIn: ExpiresInHours(room.expiresAt),
            roomId: room.id,
            teams: room.teams
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
router.post('/refresh/:id', (req, res) => {
    db.read()

    const id = parseInt(req.params.id, 10);
    
    var list = db.get("rooms").value();
    var roomId = list.findIndex(room => room.id === id);

    if(roomId != -1){
        var room = db.get("rooms").get(roomId).value();

        // When to expire
        var expires = Date.now();
        expires = expires + (86400000 * 2)// add 48h in ms
        
        if(db.get("rooms").get(roomId).set("expiresAt", expires).write()){
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
        else{
            return res.status(500).send({
                success: 'false',
                message: 'Internal error while updating expiry time',
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
router.delete('/:id', (req, res) => {
    db.read()
    const id = parseInt(req.params.id, 10);

    // Verify hardware ID
    var list = db.get("rooms").value();
    var roomId = list.findIndex(room => room.id === id);
    if(roomId == -1){
        return res.status(404).send({
            success: 'false',
            message: 'Room not found'
        });
    }
    var ownerHardwareID = db.get("rooms").get(roomId).get("ownerHardwareID").value()
    if(ownerHardwareID == req.query.hardwareID){
        if(RemoveRoom(id)){
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
// *          Players          *
// *****************************

// Join player to team on room ID
router.post('/join/:id', (req, res) => {
    db.read();
    logsDb.read()

    // Check for expired rooms and players
    RemoveExpiredRoomsAndPlayers()

    const id = parseInt(req.params.id, 10);
    
    var list = db.get("rooms").value();
    var roomId = list.findIndex(room => room.id === id);
    if(roomId != -1) var teamId = list[roomId].teams.findIndex(team => team.name === req.body.teamName)

    if(roomId != -1 && teamId != -1){
        // Check is name not taken
        var isNameTaken = false
        list[roomId].teams[teamId].players.forEach((player) => {
            if(player.name === req.body.playerName) isNameTaken = true
        })

        if(!isNameTaken){
            db.get("rooms").get(roomId).get("teams").get(teamId).get("players").push({
                "name": req.body.playerName,
                "lastSeen": Date.now(),
                "icon": req.body.icon,
                "latitude": "0",
                "longitude": "0"
            }).write()

            // log successful join action
            logsDb.get("logs").push({
                "action": "joined",
                "time": new Date().toLocaleString("pl"),
                "nickName": req.body.playerName,
                "room": roomId,
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

// Update player location on room ID
router.post('/:id', (req, res) => {
    db.read();

    const id = parseInt(req.params.id, 10);
    
    var list = db.get("rooms").value();
    var success = false;
    var roomId = list.findIndex(room => room.id === id);
    if(roomId != -1) var teamId = list[roomId].teams.findIndex(team => team.name === req.body.teamName)

    if(roomId != -1 && teamId != -1){
        success = true;

        var playerIndex = list[roomId].teams[teamId].players.findIndex(player => player.name === req.body.playerName)

        if(playerIndex > -1){
            db.get("rooms").get(roomId).get("teams").get(teamId).get("players").get(playerIndex).set("latitude", req.body.latitude).set("longitude", req.body.longitude).set("lastSeen", Date.now()).write();
        }
        else{
            return res.status(404).send({
                success: 'false',
                message: 'Player not found in this team',
            });
        }
        
        
        return res.status(200).send({
            success: 'true',
            message: 'Room found, updating location and returning players',
            teams: db.get("rooms").get(roomId).get("teams").value(),
            showEnemyTeam: db.get("rooms").get(roomId).get("showEnemyTeam").value()
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
router.post('/leave/:id', (req, res) => {
    db.read();
    logsDb.read();

    const id = parseInt(req.params.id, 10);
    
    var list = db.get("rooms").value();
    var roomId = list.findIndex(room => room.id === id);
    if(roomId != -1) var teamId = list[roomId].teams.findIndex(team => team.name === req.body.teamName)

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
            RemovePlayerFromTeam(roomId, teamId, playerToRemove);

            // log successful leave action
            logsDb.get("logs").push({
                "action": "leaved",
                "time": new Date().toLocaleString("pl"),
                "nickName": req.body.playerName,
                "room": roomId,
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


function ExpiresInHours(time){
    return ((time - Date.now()) / 1000 / 60 / 60).toPrecision(2)
}

function RemoveRoom(roomId){
    db.read();
    
    var list = db.get("rooms").value();
    var roomIndexToRemove = list.findIndex(room => room.id === roomId);
    
    if(roomIndexToRemove > -1){
        var roomToRemove = db.get("rooms").get(roomIndexToRemove).value();
        db.get("rooms").remove(roomToRemove).write()
        return true
    }
    else{
        return false
    }
}

function RemovePlayerFromTeam(roomId, teamId, player){
    db.read();

    db.get("rooms").get(roomId).get("teams").get(teamId).get("players").remove(player).write()
}

function RemoveExpiredRoomsAndPlayers(){
    db.read();

    var rooms = db.get("rooms").value()
    var roomsToRemove = []
    var playersToRemove = []

    rooms.forEach(room => {
        if(room.expiresAt < Date.now()) roomsToRemove.push(room)

        // Look for expired players
        room.teams.forEach(team => {
            team.players.forEach(player => {
                if((Date.now() - player.lastSeen) > 1000 * 60 * 35) playersToRemove.push({"player": player, "team": team, "room": room})
            })
        })
    });

    if(roomsToRemove.length > 0){
        roomsToRemove.forEach((room) => {
            db.get("rooms").remove(room).write()
        })
    }
    
    if(playersToRemove.length > 0){
        playersToRemove.forEach(obj => {
            var list = rooms
            var roomIndex = list.findIndex(room => room.id === obj.room.id);
            
            if(roomIndex > -1){
                var teamId = list[roomIndex].teams.findIndex(team => team.name === obj.team.name)

                if(teamId > -1){
                    RemovePlayerFromTeam(roomIndex, teamId, obj.player)
                }           
            }
        })
    }
}

module.exports = router