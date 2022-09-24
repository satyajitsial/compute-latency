# Kong compute-latency Plugin
## Overview
This plugin will help to calculate and send time taken by kong plugins ae well as custom plugins.
When the plugin is applied with series of plugins during a request cycle, It 
will calculate and send the time taken by the other plugins and sends it as header. 

## Tested in Kong Release
Kong Enterprise 2.7.1.2

## Installation
### Recommended
```
$ git clone https://github.com/satyajitsial/compute-latency.git
$ cd compute-latency
$ luarocks make kong-plugin-compute-latency-0.1.0-1.rockspec
```
### Other

```
$ git clone https://github.com/satyajitsial/compute-latency.git
$ cd compute-latency
$ luarocks install kong-plugin-compute-latency-0.1.0-1.all.rock
```
After Installing the Plugin using any of the above steps . Add the Plugin Name in Kong.conf

```
plugins = bundled,compute-latency

```
### Restart Kong

```
kong restart

```
# Configuration Reference

## Enable the plugin on a service

### Admin-API
For example, configure this plugin on a service by making the following request:
		
	curl -X POST http://{HOST}:8001/services/{SERVICE}/plugins \
	--data "name=compute-latency"  \
	--data "config.plugin_suffix={PLUGIN_SUFFIX}"

### Declarative(YAML)
For example, configure this plugin on a service by adding this section to your declarative configuration file:
			
	services : 
	 name: {SERVICE}
	 plugins:
	 - name: compute-latency
	 config:
	   plugin_suffix: {PLUGIN_SUFFIX}
	 enabled: true
	 protocols:
	 - grpc
	 - grpcs
	 - http
	 - https

SERVICE is the id or name of the service that this plugin configuration will target.
PLUGIN_SUFFIX is the suffix string to be added after each plugin name in the header.

## Enable the plugin on a Route

### Admin-API
For example, configure this plugin on a route with:

	curl -X POST http://{HOST}:8001/services/{ROUTE}/plugins \
	--data "name=compute-latency"  \
	--data "config.plugin_suffix={PLUGIN_SUFFIX}"
### Declarative(YAML)
For example, configure this plugin on a route by adding this section to your declarative configuration file:

	services : 
	 name: {ROUTE}
	 plugins:
	 - name: compute-latency
	 config:
	   plugin_suffix: {PLUGIN_SUFFIX}
	 enabled: true
	 protocols:
	 - grpc
	 - grpcs
	 - http
	 - https

ROUTE is the id or name of the route that this plugin configuration will target.
PLUGIN_SUFFIX is the suffix string to be added after each plugin name in the header.

## Parameters

| FORM PARAMETER	     														| DESCRIPTION										  													|
| ----------- 																		| -----------																								|
| name<br>Type:string  														|  The name of the plugin to use, in this case compute-latency |
| service.id<br>Type:string  										  |  The ID of the Service the plugin targets.								|
| route.id<br>Type:string   											|  The ID of the Route  the plugin targets.									|
| enabled<br>Type:boolean<br>Default value:true   |  Whether this plugin will be applied.										  |
| config.plugin_suffix<br>Type:string              |  Accepts a suffix string and that has to be added after each plugin name|



## Contributors
Developed By : Satyajit.Sial@VERIFONE.com <br>
			   Prema.Namasivayam@VERIFONE.com <br>
Guided By    : Vineet.Dutt@VERIFONE.com , krishna_p2@VERIFONE.com  