This mod makes using passive provider chests and requester chests easier.

.For a visual explanation have alook at
<https://imgur.com/a/vt1ar>

Upon placement of a requester chest all inserters that have that new chest as pickup location have the machines at their droplocations evaluated. For every furnace/machine the material consuption gets calculated, is multiplied by the configured amount and is added to the request of the requester chest. 

Upon placement of a passive provider chest all Inserters that have this chest as dropoff location have the machines at their pickup location evaluated. For every furnace/machine the procduction gets calculated. Depending on the configuration the inserter is connected through red or green wire or directly to the logistic network. The inserter is set to only be active when the produced item in the chest or in the network is below the threshhold.
The threshhold is calculated through the production of the machine.

Upon Placement of a inserter get entitys on pickup and drop location and if it's a logistic chest goes through the same logic.

How is it calculated?
The consumption and production takes moduls and beacons into consideration.
If not enough electricity ist available the reported speed will be wrong, so take care that everything is at 100%.
First the rate per second is calculated. The value is then multiplied by the configurated number of seconds.
If the craftingtime is greater than the configurated seconds the value of one craft is used.

Configuration:
Buffertime requester: For how many seconds should material be requested?
Buffertime Provider: Of how many seconds should products be stored?
Type of connection of provider: How should the Inserter be connected to the provider chest?

Setting a option to 0 deactivates that feature.