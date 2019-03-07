This mod makes using passive provider chests and requester chests easier.

.For a visual explanation have alook at
<https://imgur.com/a/vt1ar>

Upon placement (bot and manual)  of arequester chest all inserters that have that new chest as pickup location have the machines at their droplocations evaluated. For every furnace/machine the material consuption gets calculated, is multiplied by the configured amount and is added to the request of the requester chest. 

Upon placement (bot and manual)  of a passive provider chest all Inserters that have this chest as dropoff location have that machines at their pickup location evaluated. For every furnace/machine the procduction gets calculated. Depending on the configuration the inserter is connected through red or green wire or directly to the logistic network. The inserter is set to only be active when the produced item in the chest or in the network is below the threshhold.
The threshhold is calculated through the production of the machine.

How is it calculated?
The consumption and production takes moduls and beacons into consideration.
First the rate per second is calculated. The value is then multiplied by the configurated number of seconds.
If the craftingtime is greater than the configurated seconds the value of one craft is used.

Configuration:
Buffertime requester: For how many seconds should material be requested?
Buffertime Provider: Of how many seconds should products be stored?
Type of connection of provider: How should the Inserter be connected to the provider chest?

Setting a option to 0 deactivates that feature.

Changelog:
0.7005.33974
Changed to 0.17.
Untested!

0.6579.27338
Added german localisation

0.6578.39285
Fixed detection of existing conditions.

0.6578.31914
Added option to not override existing inserter conditions.
Added option to only use modlogic when chest placed manually, by bot or by both.
Changed logic to use entity.effects

0.6577.34562
Added choice how to connect the provider.

0.6572.42672
Port to 0.16