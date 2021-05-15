# SQL DEVELOPER KURZUSHOZ TELEPÍTÉSI SEGÉDLET 1 CORE SERVER + 1 CLIENT BEÁLLÍTÁSÁVAL OTTHONI FIZIKAI KÖRNYEZETBEN VIRTULIZÁCIÓ HASZNÁLATÁVAL EMULÁLT ACTIVE DIRECTORY STRUKTÚRÁBAN

> **HOZZÁVALÓK**

 * 2 db számítógép (a példában egy laptop 8G RAM-al, egy desktop 4G RAM-al)
 * valamilyen virtualizációs rendszer ismerete, használata windows gazdarendszerekre inkább vmware, linuxra inkább kvm.
 * A kvm-servernek szánt gépen systemctl stop sddm-el (sddm GUI-s bejelentkező esetén) érdemes a GUI-t teljesen leállítani nincs rá szükség.
 * ssh és sshfs kapcsolat a terminálnak szánt rendszerről a servernek szánt rendszerre. ssh tunnel kell (!!)
 * telepített fuse,ntfs-3g csatolási segédeszközök

> **KIINDULÁSI TOPOLÓGIA**

![](img/home1.png)

> **1. lépés: VDE Telepítése laptop 8G serverre, ha VMWARE-t használsz ez elhagyható**

`apt install vde2`

 * Telepítés után be kell állítani. Telepítéskor létrejön egy vde2-net nevű csoport egy vde2-net nevű felhasználónévvel. 
 * A `/etc/group` fileba a vde2-net csoportba be kell tenni azt a felhasználót akinek a nevében majd a kvm virtuális gép van. jelen példában (lagoth).
 * A virtuális switch paramétereit be kell állítani (a MAC cím tetszés szerinti, csak eltérő legyen a meglevő eszközöktől). Debian rendszerekben a `/etc/network/interfacees`-ben lehet beállítani a következő sorok beírásával. Az emulációhoz a tun/tap alrendszert használja amit a networkmanager (nmcli)-hez hasonló eszközök általában nem ismernek fel, ezért célszerű kézzel beírni. A módosítás után a hálózati alrendszert / vagy a gazdagépet újra kell indítani. 

`auto tap0` / ha nem akarod elindítani bootoláskor ezt ki kell kommentelni. De akkor a tap0 eszközt manuálisan kell elindítani /

`iface tap0 inet static`

`    hwaddress f6:2b:23:50:7a:3c`

`    address 192.168.2.254`

`    netmask 255.255.255.0`

`    pre-up /usr/bin/vde_switch --tap tap0 --sock /var/run/vde.ctl \`

`                        --daemon --group vde2-net --mod 775 \`

`                        --mgmt /var/run/vde.mgmt --mgmtmode 770 \`

`                        --pidfile /var/run/vde_switch.pid`

`    post-down kill -s KILL $(cat /var/run/vde_switch.pid);rm /var/run/vde_switch.pid;rm /var/run/vde.ctl/ctl;rm /var/run/vde.mgmt`

Ha mindez megtörtént az `ip a` parancssal már látni kell a tap0 virtuális switchet.

 * Ezután be kell állítani, hogy a tap0 routerként viselkedjen átengedje a forgalmat, és NAT-olja a fizikai hálózat felé, hogy a tap0 mögött álló eszközök elérjék az internetet.

Előszőr is a gazdagépen be kell állítani a csomagirányítást hogy a hálózati interfacek egymásnak tudjanak csomagot küldeni. Ez lehet pl. a `/etc/sysctl.conf'-ban de a módosítások csak újraindítás után lépnek életbe. A következő sort módosítani kell 0-ról:
`net.ipv4.ip_forward=1`
Célszerű beszúrni a következő sort is:
`net.ipv4.conf.lo.forwarding=0`
Az első engedi a forgalmat a hálózati interfacek között a második kivételként a loopback-et felveszi, hogy azon ne történjen csomagátirányítás.

majd az iptables rendszerben be kell állítani a NAT funkciót az internet eléréséhez (internetkapcsolat wlan0 eszközön):

`iptables -t nat -o wlan0 -s 192.168.2.0/24 -j MASQUERADE`

Amennyiben használsz korlátozó tűzfalszabályokat az iptables FORWARD táblát is be kell állítani a 2 interféce között.

Így az alábbi topológia már kialakítható:

![](img/sql2.png)


> **2. lépés: virtuális Windows 2016 Server létrehozása**

 * `qemu-img create w2016.raw 22G` parancssal létre kell hozni a merevlemezt amire a win2016 server kerül.

 * Virtuális gép elindítása:

`kvm -daemonize -monitor telnet:127.0.0.1:33011,server,nowait,ipv4 -name windows2016 -smp 1 -rtc base=localtime -spice port=6090,addr=127.0.0.1,disable-ticketing,image-compression=off -vga qxl -k hu -m 4096 -drive file=w2016.raw,format=raw,if=ide -cdrom w2k16.iso -device virtio-serial-pci,id=virtio-serial0,max_ports=16,bus=pci.0,addr=0x5 -chardev spicevmc,name=vdagent,id=vdagent -device virtserialport,nr=1,bus=virtio-serial0.0,chardev=vdagent,name=com.redhat.spice.0 -soundhw hda -boot d -net nic,macaddr=cb:31:0f:29:38:7f -net vde`

A qemu telnet port localhost:33011-re a kimenet spice protokollon localhost:6090-re kerül a másik fizikai gépről ssh tunnellel problémamentesen elérhetőek. A -cdrom csatolja be a telepítőcd-t, illetve előkészíti a spice agent használatát webdav-al.A MAC cím szabadon választható , csak olyan legyen amit másik eszköz még nem használ. 4G RAM-ot használ a virtuális gép.

Telepítéskor a Standard Evaluation teszi fel a Win2k16 core servert. A terminálos gépről ssh tunnel-en keresztül elérhető a 33011-es port `telnet localhost 33011` parancssal amennyiben a terminál szintén a 33011-et használja a tunnelhez.

Így tudod beküldeni a ctrl-alt-del kombinációt a bejelentkezéshez:

![](img/sendkeys.png)

Ezután már be tudsz jelentkezni az admin. jelszóval:

![](img/sendkeys2.png)

Majd az `sconfig` parancssal célszerű átírni a gépnevet pl. CORE-ra. Ezután restart.

![](img/corename.png)

Majd ismét `sconfig` és beállítani a hálózatot a 8-as menüponttal:

![](img/topology.png)

Így már lesz internet:

![](img/internet.png)

Az AD telepítéshez érdemes létrehozni egy új felhasználót: (példában archmage)

![](img/archmage.png)

Majd állítsuk le a servert (shutdown) 14-es menüpont.

Jelentkezzünk át a gazdagépen root jogba és fdisk-el nézd meg a w2016.raw (windows 2016 virtuális merevlemez) partíciós tábláját:

![](img/fdisk1.png)

Itt ki kell számítani az offset értéket.

Ez `szektorszám*szektorkezdet`.

A 21,5G méretű partíciónál ez `512*1026048=525336576`

A virtuális merevlemezt így a serveres gazdagépen már be lehet csatolni pl.
`mount -o loop,offset=525336576 w2016.raw /srv` parancssal. Így a terminálos asztali gépről sshfs-en keresztül fel lehet másolni a laptopon levő leállított w2016 server merevlemezére telepítendő fájlokat.

pl. létrehozás után a mytools könyvtárba.

![](img/filecopy.png)

Ezután csatold le a /srv-ről a merevlemezt és indítsd el újra a w2016 servert és jelentkezz be az új admin felhasználóval (archmage). A C:\mytools mappában benne lesznek a segédeszközök.

Előszőr a spice-guest-tools-t kell feltelepíteni. A tool [itt](https://www.spice-space.org/download/windows/spice-guest-tools/spice-guest-tools-latest.exe) elérhető.

![](img/spicetools.png)

Ezután spice-on keresztül már működik a vágólap a terminálos fizikai gép a laptop(server) en futó virtuális windows 2016 server között. a spice kliensnél a (**mouse:client,agent=yes**) jelzi hogy működik a spice-tools. Ez vmware-tools-hoz hasonló eszköz csak qemu/kvm környezetben.

Telepítsük fel az admincentert. A telepítési fájl [itt](https://aka.ms/WACDownload) érhető el közvetlenül. A telepítési automata batch fájl peddig [itt](scripts/admininstall.bat). Semmit nem kérdez.

![](img/admincenter1.png)


Még nem tudunk rá bejelentkezni mert a Windows Firewall blokkolja, AD telepítés jön tűzfalbeállításokkal. `powershell` parancssal kell indítani. A példához használt PS1 script [itt](scripts/coreserver2.ps1) elérhető. Vigyázat ez sem kérdez semmit kérdés nélkül beállít mindent a példa alapján !

![](img/adinstall.png)

Az AD telepítés után működik az Admin Center. eszközkezelő, tűzfal, ill. fájlmozgatáshoz lehet kiválóan használni. Néha lassú...
Ne felejtsd el, hogy a terminal asztali kliensről ssh tunnelt be kell állítani a virtuális gép adott portjára. Ebben a példában `-L 43443:192.168.2.38:6571` -es ssh kliens opcióval.

![](img/admincenter2.png)

TODO...