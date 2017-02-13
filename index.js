import {
	DeviceEventEmitter,
	NativeModules
} from 'react-native';

var Mqtt = NativeModules.Mqtt;

var MqttClient = function(options, clientRef){
	this.options = options;
	this.clientRef = clientRef;
	this.eventHandler = {};

	this.dispatchEvent = function(data) {
		
		if(data && data.clientRef == this.clientRef && data.event) {

			if(this.eventHandler[data.event]) {
				this.eventHandler[data.event](data.message);
			}
		}	
	}
}

MqttClient.prototype.on = function (event, callback) {
	this.eventHandler[event] = callback;
}

MqttClient.prototype.connect = function () {
	Mqtt.connect(this.clientRef);
}

MqttClient.prototype.disconnect = function () {
	Mqtt.disconnect(this.clientRef);
}


MqttClient.prototype.subscribe = function (topic, qos) {
	Mqtt.subscribe(this.clientRef, topic, qos);
}

MqttClient.prototype.publish = function(topic, payload, qos, retain) {
	Mqtt.publish(this.clientRef, topic, payload, qos, retain);
}

module.exports = {
	clients: [],
	eventHandler: null,
	dispatchEvents: function(data) {
		this.clients.forEach(function(client) {
			client.dispatchEvent(data);
		});
	},
	createClient: async function(options) {
		if(options.uri) {
			var pattern = /^((mqtt[s]?|ws[s]?)?:(\/\/)([a-zA-Z_\.]*):?(\d+))$/;
			var matches = options.uri.match(pattern);
			var protocol = matches[2];
			var host = matches[4];
			var port =  matches[5];

			options.port = parseInt(port);
			options.host = host;
			options.protocol = 'tcp';
			

			if(protocol == 'wss' || protocol == 'mqtts') {
				options.tls = true;
			}
			if(protocol == 'ws' || protocol == 'wss') {
				options.protocol = 'ws';
			}
			
		}
		
		let clientRef = await Mqtt.createClient(options);

		var client = new MqttClient(options, clientRef);

		/* Listen mqtt event */
		if (this.eventHandler === null) {
			this.setEventHandler();
		}

		this.clients.push(client);

		return client;
	},
	setEventHandler: function() {
		this.eventHandler = DeviceEventEmitter.addListener("mqtt_events", (data) => this.dispatchEvents(data));
	},
	removeClients: function () {
		this.clients = [];
		if (this.eventHandler !== null) {
			this.eventHandler.remove();
			this.eventHandler = null;
		}
	},

	removeClient: function(client) {
		var clientIdx = this.clients.indexOf(client);

		/* TODO: destroy client in native module */
		Mqtt.removeClient(client.clientRef)
			.then(() => {
				//if found, remove from this.clients array
				if (clientIdx > -1)
					this.clients.splice(clientIdx, 1);

				//if this.clients array after removal contains anything
				if (this.clients.length > 0) {
					if (this.eventHandler !== null) {
						this.eventHandler.remove();
						this.eventHandler = null;
						//shouldn't we add the listeners again?
						this.setEventHandler();
					}
				}
			});
	}
	
};
