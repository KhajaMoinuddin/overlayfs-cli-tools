# overlayfs-cli-tools
simple cli tools for overlayfs

## Usage
1. Login as root
2. git clone this repo
3. set env var LAYERS_DIR
3. Add the repo directory to PATH

* mount an new layer
```bash
mkdir /root/d1
cd /root/d1
new.layer l0
```
* list existing layers
```bash
list.layer
tag                     directory                       position
-----------------------------------------------------------------
l0                      /root/layers/000
l1                      /root/layers/001                HEAD
```
* select a layer
```bash
select.layer /root/d1 l0
tag                     directory                       position
-----------------------------------------------------------------
l0                      /root/layers/000                HEAD
l1                      /root/layers/001
```
* delete a layer
```bash
delete.layer /root/d1 l0
```
* delete all layer
```bash
delete.layer /root/d1
```
