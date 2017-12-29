This mod makes using passive provider chests and requester chests easier.

How does it work?
Requester chest: Upon placement of the chest all Inserters that have this chest as pickup location have their droplocations evaluated.
For every furnace/machine the material consuption gets calculated and is added to the request of the requester chest.
Passiv provider chest: Upon placement of the chest all Inserters that have this chest as dropoff location have their pickup location evaluated. For every furnace/machine the procduction gets calculated. Then the inserter is connected per circuit network to the chest.
The Chest is set to read it's contents and the inserter is set to only be active when the produced item in the chest is below the threshhold.

How is it calculated? The consumption and production takes moduls and beacons into consideration.
First the rate per second is calculated. The value is then multiplied by the configurated number of seconds.

Configuration:
Buffertime requester: For how many seconds should material be requested?
BuffertimeProvider: Of how many seconds should products be stored?

Setting a option to 0 deactivates that feature.
