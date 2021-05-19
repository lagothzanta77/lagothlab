# SQL DEVELOPER KURZUSHOZ TELEPÍTÉSI SEGÉDLET 1 CORE SERVER + 1 CLIENT BEÁLLÍTÁSÁVAL OTTHONI FIZIKAI KÖRNYEZETBEN VIRTULIZÁCIÓ HASZNÁLATÁVAL EMULÁLT ACTIVE DIRECTORY STRUKTÚRÁBAN

> **HOZZÁVALÓK**

 * 2 db számítógép (a példában egy laptop 8G RAM-al, egy desktop 4G RAM-al)
 * valamilyen virtualizációs rendszer ismerete, használata windows gazdarendszerekre inkább hyper-v, vagy vmware - inkább esxi mint workstation player -, linuxra inkább kvm.
 * A kvm-servernek szánt gépen nem kell bejelentkezni. Ha a rendszeren a vbetool nem működik a képernyő lekapcsolására parancssori felületen az sddm gui bejelentkező használható képernyő lekapcsoláshoz (xorg dpms serverflags). Amennyiben működik pl. systemctl stop sddm-el lekapcsolható egy sddm gui ablakkezelő.
 * ssh és sshfs kapcsolat a terminálnak szánt rendszerről a servernek szánt rendszerre. ssh tunnel kell (!!)
 * telepített fuse,ntfs-3g csatolási segédeszközök

> **KIINDULÁSI TOPOLÓGIA**

![](img/home1.png)

> **1. lépés: VDE Telepítése laptop 8G serverre, ha VMWARE-t/hyper-V-t használsz ez elhagyható**

`apt install vde2`

 * Telepítés után be kell állítani. Telepítéskor létrejön egy vde2-net nevű csoport egy vde2-net nevű felhasználónévvel. 
 * A `/etc/group` fileba a vde2-net csoportba be kell tenni azt a felhasználót akinek a nevében majd a kvm virtuális gép fut. jelen példában (lagoth).Szükséges lehet a kvm csoportba is betenni.
 * A virtuális switch paramétereit be kell állítani (a MAC cím tetszés szerinti, csak eltérő legyen a meglevő eszközöktől). Debian rendszerekben a `/etc/network/interfaces`-ben lehet beállítani a következő sorok beírásával. Az emulációhoz a tun/tap alrendszert használja amit a networkmanager (nmcli)-hez hasonló eszközök általában nem ismernek fel, ezért célszerű kézzel beírni. A módosítás után a hálózati alrendszert / vagy a gazdagépet újra kell indítani. 

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

Előszőr is a gazdagépen be kell állítani a csomagirányítást hogy a hálózati interfacek egymásnak tudjanak csomagot küldeni. Ez lehet pl. a `/etc/sysctl.conf`-ban de a módosítások csak újraindítás után lépnek életbe. A következő sort módosítani kell 0-ról:

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

 * `qemu-img create w2016.raw 34G` parancssal létre kell hozni a merevlemezt amire a win2016 server kerül.

 * Virtuális gép elindítása célszerű bash szkriptből:

`export QEMU_AUDIO_DRV="none"`

`kvm -daemonize -monitor telnet:127.0.0.1:33011,server,nowait,ipv4 -name windows2016 -smp 4 -rtc base=localtime -spice port=6090,addr=127.0.0.1,disable-ticketing,image-compression=off -vga qxl -k hu -m 3072 -drive file=w2016.raw,format=raw,if=ide -cdrom w2k16.iso -device virtio-serial-pci,id=virtio-serial0,max_ports=16,bus=pci.0,addr=0x5 -chardev spicevmc,name=vdagent,id=vdagent -device virtserialport,nr=1,bus=virtio-serial0.0,chardev=vdagent,name=com.redhat.spice.0 -soundhw hda -boot d -net nic,macaddr=cb:31:0f:29:38:7f -net vde`

A qemu telnet port localhost:33011-ra, a képernyő a spice protokollon localhost:6090-re kerül a másik fizikai gépről ssh tunnellel problémamentesen elérhetőek. A -cdrom csatolja be a telepítőcd-t, illetve előkészíti a spice agent használatát, hangra server esetében nincs szükség.A MAC cím szabadon választható, csak olyan legyen amit másik eszköz még nem használ. 3G RAM-ot használ a virtuális gép.
Egy 8 total thread-es (`core*thread`) processzor esetében (`cat /proc/cpuinfo | grep -c proc`) 4-t adhatsz a servernek, 2 marad a gazdarendszernek és 2 jut majd az AD kliensnek.

Telepítéskor a Standard Evaluation teszi fel a Win2k16 core servert. A terminálos gépről ssh tunnel-en keresztül elérhető a 33011-es port `telnet localhost 33011` parancssal amennyiben a terminál szintén a 33011-et használja a tunnelhez.

Így tudod beküldeni a ctrl-alt-del kombinációt a bejelentkezéshez:

![](img/sendkeys.png)

Ezután már be tudsz jelentkezni az admin. jelszóval:

![](img/sendkeys2.png)

Majd az `sconfig` parancssal célszerű átírni a gépnevet pl. CORE-ra. Ezután restart.

![](img/corename.png)

Majd ismét `sconfig` és beállítani az időt, **időzónát** a 9-es és a hálózatot a 8-as menüponttal:

![](img/topology.png)

Így már lesz internet:

![](img/internet.png)

Az AD telepítéshez érdemes létrehozni egy új felhasználót: (példában archmage)

![](img/archmage.png)

Majd állítsd le a servert (shutdown) 14-es menüpont.

Jelentkezz át a gazdagépen root jogba és fdisk-el nézd meg a w2016.raw (windows 2016 virtuális merevlemez) partíciós tábláját:

![](img/fdisk1.png)

Itt ki kell számítani az offset értéket.

Ez `szektorszám*szektorkezdet`.

A 21,5G méretű partíciónál ez `512*1026048=525336576`

A virtuális merevlemezt így a serveres gazdagépen már be lehet csatolni pl.

`mount -o loop,offset=525336576 w2016.raw /srv`

parancssal. Így a terminálos asztali gépről sshfs-en keresztül fel lehet másolni a laptopon levő leállított w2016 server merevlemezére telepítendő fájlokat.

pl. létrehozás után a mytools könyvtárba.

![](img/filecopy.png)

Ezután csatold le a /srv-ről a merevlemezt és indítsd el újra a w2016 servert és jelentkezz be az új admin felhasználóval (archmage). A C:\mytools mappában benne lesznek a segédeszközök.

Előszőr a spice-guest-tools-t kell feltelepíteni. A tool [itt](https://www.spice-space.org/download/windows/spice-guest-tools/spice-guest-tools-latest.exe) elérhető.

![](img/spicetools.png)

Ezután spice-on keresztül már működik a vágólap a terminálos fizikai gép a laptop(server) en futó virtuális windows 2016 server között. A spice kliensnél a (**mouse:client,agent=yes**) jelzi hogy működik a spice-tools. Ez vmware-tools-hoz hasonló eszköz csak qemu/kvm környezetben.

Telepítsd fel az admincentert. A telepítési fájl [itt](https://aka.ms/WACDownload) érhető el közvetlenül. A telepítési automata batch fájl peddig [itt](scripts/admininstall.bat). Semmit nem kérdez.

![](img/admincenter1.png)


Ezután AD telepítés jön tűzfalbeállításokkal. `powershell` parancssal kell indítani. A példához használt PS1 script [itt](scripts/coreserver2.ps1) elérhető. Vigyázat ! Ez sem kérdez semmit, kérdés nélkül beállít mindent a példa alapján (DC=core.sqlcourse.local) !

![](img/adinstall.png)

Az AD telepítés után működik az Admin Center a példában elmozgatva a 6571-es porton. eszközkezelő, tűzfal, ill. fájlmozgatáshoz lehet kiválóan használni. Néha lassú...
Ne felejtsd el, hogy a terminal asztali kliensről ssh tunnelt be kell állítani a virtuális gép adott portjára. Ebben a példában `-L 43443:192.168.2.38:6571` -es ssh kliens opcióval.

![](img/admincenter2.png)

Ha helyhiány lép fel, a virtuális gép leállítása után ki tudod terjeszteni a virtuális rendszermerevlemezt is.

`qemu-img info w2016.raw`

kiírja hogy mennyi a virtuális merevlemez mérete (34G), jelenleg mennyi helyet foglal merevlemezen (26G)

Pl. Így lehet 8G-vel megnövelni: (A RAW formátumot csak lecsatolt nem használt állapotban lehet átméretezni)

`qemu-img resize -f raw w2016.raw +8G`

Ezután :

`qemu-img info w2016.raw`

parancs kimenete:

`image: w2016.raw`

`file format: raw`

`virtual size: 42G (45097156608 bytes)`

`disk size: 26G`


Ez csak a virtuális merevlemez "fizikai" mérete, még a rendszerpartíciót is meg kell növelni (NTFS), pl. admincenter révén.

![](img/resizedisk.png)

A korábbi frissítési fájlok, összevont patchek telepítőkészletének eltávolításával is lehet helyet sprórolni:

`Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase`

A parancs forrása [itt](https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/clean-up-the-winsxs-folder).

A qemu monitoros telnet parancsok is szkriptelhetőek except segítségével. [Itt](scripts/expectexample.sh) egy mintapélda ami az "info status" parancsot futtatja. De le lehet cserélni pl. drive-backupra :-)

> **3. lépés: Egy windows 10-es PRO klienst kell telepíteni**

 (pl. w10p.img mint raw disk image,monitor port 33021,spice port 6091) a virtuális hálózatba 192.168.2.217/24-es ip címmel a példa alapján.
 
Erre lehet webdavot is telepíteni. Itt is kell spice-guest-tools, és ajánlott mellé spice-webdavd szolgáltatást is telepíteni. [Itt](https://www.spice-space.org/download/windows/spice-webdavd/spice-webdavd-x64-latest.msi) elérhető.

`export QEMU_AUDIO_DRV=spice`

`kvm -daemonize -name windows10 -monitor telnet:127.0.0.1:33021,server,nowait,ipv4 -smp 2 -rtc base=localtime -spice port=6091,addr=127.0.0.1,disable-ticketing,image-compression=off -vga qxl -k hu -m 3584 -drive file=w10p.img,format=raw,if=ide -cdrom Win10_20H2_v2_Hungarian_x64.iso -device virtio-serial-pci,id=virtio-serial0,max_ports=16,bus=pci.0,addr=0x5 -chardev spicevmc,name=vdagent,id=vdagent -device virtserialport,nr=1,bus=virtio-serial0.0,chardev=vdagent,name=com.redhat.spice.0 -soundhw hda -boot d -net nic,macaddr=cb:31:0f:29:3b:70 -device virtserialport,bus=virtio-serial0.0,nr=2,chardev=charchannel1,id=channel1,name=org.spice-space.webdav.0 -chardev spiceport,name=org.spice-space.webdav.0,id=charchannel1 -net vde`

A spice kliensben ezután meg tudsz adni egy mappát a desktop (terminal) gépen, ami hálózati meghajtóként elérhető a laptopon (server) futó virtuális (kvm) win10 kliens számára. Így ide is könnyen be lehet juttatni/ki lehet szedni fájlokat. Ennek a hálózati meghajtónak jobb a teljesítménye, mint az RDP-nek. A Management Studonak sok ramra van szüksége, ezért a kliens kap többet 3,5 G-t a példában.

pl. `spicy --spice-shared-dir=./spicy`

![](img/webdav.png)

Sajnos a 2. virtuális gép a laptopon már valószínűleg lassan indul. A bootolás sajnos lassú gépen lassú lesz. Bootolás befejeződése után már használható sebessége van.

Itt már meg tudsz adni hang kimenetet is (spice), úgyhogy a windows kliensnek lesz hangja amit ssh tunnelen keresztül az asztali (terminal) géped hangkimenetén hallasz.

Most telepítsd fel a windows szolgáltatásokból az [RSAT](https://docs.microsoft.com/en-us/troubleshoot/windows-server/system-management-components/remote-server-administration-tools) modulokat.

![](img/rsat.png)

Az AD Domain Services, a DNS Server, a kiszolgálókezelő, és a csoportházirendes cucc mindenképpen legyen fent.

Az ADMIN centerből lehet kezelni a server lokális beállításait ( eszközkezelő, merevlemez), de az active directoryt mint logikai egységet csak nehézkesen. Ezek majd ahhoz kellenek.


> **4. lépés: A win 10-et be kell léptetni a tartományba (sqlcourse.local)**

Át kell írni a DNS servert a DC server (core) ip címére.

![](img/domain1.png)

Ellenőrzés ping-el, ha válaszol, be lehet léptetni a korábban létrehozott domain admin userrel (archmage)

![](img/domain2.png)

Ennyi.

![](img/domain3.png)


Újraindítás és core server admin joggal történő bejelentkezés után egy `mmc.exe` futtatásával hozzá lehet adni az `Active Domain Users and Computers`-t. Mindjárt érdemes hozzáadnod magadnak `Domain Admin` csoporttagságot, és legyen ez az elsődleges csoport. Sok hozzáférési problémát megold. A core server engedi fogja erről a gépről a kapcsolatot, mivel az AD telepítésekor használt powershell szkript előrelátóan tartalmazta a szükséges tűzfalszabályt erre a windows 10-es kliensgépre. (192.168.2.217)

![](img/domain4.png)

Ne felejtsd el hozzáadni a DNS serverhez  - csatlakozáskor a számítógép neve a core server neve ( itt pl. CORE ) - a hálózat reverse lookup zónáját!

![](img/dnsserver.png)

> **5. lépés: SQL Server telepítési előkészületei**

  * Az SQL servernek majd 4 darab spec. felhasználóra van szüksége tartományi szinten, akinek nevében futtatja majd a cuccát. Mivel DC-n fog futni ezért `domain managed service user`-ekre lesz szüksége. Hozd őket létre ! Valamint készíts 2 normál domain usert is (pl. wizard, magician). Az egyik lesz az sql. másik az analysis administrator. A domainben nekik normál felhasználói joguk, az sql-ben/analysis service-ben adminisztrátori joguk lesz.

![](img/sqlservice1.png)

![](img/sqlservice2.png)

A másik kettőt ugyanígy.

 1. SQL service
 1. Analysis Service
 1. Agent Service
 1. Integrated Service

**Mindegyiknek fontos hogy megfelelő jelszava legyen. A jelszót ne felejtsd el**


A Windows 10-en administratori módban indított `windows powershell` -ben kiadott

 `Enable-PSRemoting`

után már windows admin centerből kezelhető ez a gép is - ebben a példában archmage@sqlcourse.local néven -, a tárolók között a webdav-os spice hálózati meghajtó viszont nem feltétlen jelenik meg az admin centerben.
Ezután a Windows 10 lokális meghajtói is elérhetőek az Admin Centerből, eltávolíthatod róla a spice-webdavd-t ha akarod.

![](img/winrm.png)

A két rendszert egy szkriptből is el tudod indítani, de érdemes úgy megírni (mint ebben a példában), hogy amíg nem tudod pingelni a DC-t addig ne indítsd el a klienset. Ugyanis a DC-nek több mindent kell elindítani, a bootolás jobban terheli a host processzorát, és amíg a DC nem működik a kliens sem tud rá bejelentkezni. 
Egy példa [itt](scripts/winAD.sh) elérhető. 

A windows2016server.sh tartalmazza a serverindítási kvm parancsot a windows10pro a kliensét a kettő között pedig van egy kis késleltetés.

Most le kell tölteni az sql server developer edition ISO fájlt valamelyik gépre az sql netes telepítővel.
Az én választásom a core server.

Az [SQL Server 2019](https://www.microsoft.com/en-us/sql-server/sql-server-downloads)-es [itt](https://go.microsoft.com/fwlink/?linkid=866662) érhető el.

![](img/sqlsetuppre.png)

Admin centerrel át kell másolni a kvm-es gazdagépre (laptop). Ezután a letöltött iso fájl a virtuális gépről már törölhető. Ha KVM helyett vmware/hyper-v t használsz windowsos HOST-on , akkor közvetlenül indíthatod a netes telepítőd és letöltheted egyből a gazdagépre az iso fájlt.

![](img/sqldeveliso1.png)

A server virtuális cd meghajtójában eddig a win2016 telepítő volt, ki kell cserélni az sql telepítőlemezre.

![](img/develiso.png)

Ezután a `D:\` meghajtón már az sql telepítő érhető el. Ez élő rendszeren elvégezhető, nem kell lekapcsolni a virtuális gépet.

> **6. lépés: SQL server telepítése a Domain Controlleren.**

Nem tartják jó ötletnek DC-re telepíteni, de ez egy labor környezet oktatási célra korlátozott erőforrásokkal. Itt az SQL server DC-n lesz.

A megfelelően előregyártott szkripttel (batch fájl, [itt](scripts/sqlsetup.bat) elérhető) és a hozzá kapcsolódó telepítési beállítóval (ini fájl, [itt](scripts/sqlinstall.ini) elérhető) a telepítést automatikusan elvégezheted, az sql domain administrator a wizard felhasználó lesz a példában.

**A batch fájlban a jelszavakat át kell írnod arra, amit megadtál a 4 db sql domain service account létrehozásakor.**


Az SQL instance a c:\mssql könyvtárba kerül.

A példaszkriptek a core serveren a `c:\mytools\" mappában vannak. A telepítő cd pedig a D:\ meghajtón.

Ez a szkript sem kérdez semmit.

![](img/sqlsetup2.png)

Ezzel az sql server telepítése kész.

> **7. lépés: SQL Server beállítása**

A win10pro-ra lépj be az sql administrator (domain user) kóddal. (itt: wizard), majd az sql serverbe mssms-val.

![](img/wizconnect.png)

Állítsd át a servert windows auth + **sql auth** módba.

![](img/wizconnect2.png)

Indítsd újra az sql service-t (pl. admin centerből)

![](img/servrestart.png)

Hozz létre egy teljes jogú sql auth. módú sql felhasználót. (pl. sorcerer)

![](img/sorcerer1.png)

Ha mindent alapbeállításon hagytál 1. bejelentkezés után jelszót kell cserélned.

![](img/sorcerer2.png)

Ezzel a core serveren tudsz parancssori sqlcmd-t használni

![](img/sorcerer3.png)

Ha van másik nem windowsos géped a hálózaton azure data studióval rá tudsz csatlakozni a serverre
a win10p helyett. Ehhez szükséged lehet a core serveren tűzfal állításra.

![](img/sorcerer4.png)
