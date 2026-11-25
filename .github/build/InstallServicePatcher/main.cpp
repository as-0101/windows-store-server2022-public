// InstallServicePatcher: offline, fail-closed compatibility patcher for Windows Server 2022 x64.
// Input: path to a detached original InstallService.dll. Never modifies Windows permissions.
#include <algorithm>
#include <cstdint>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <iterator>
#include <limits>
#include <stdexcept>
#include <string>
#include <vector>
#include "Payload.h"
namespace fs = std::filesystem;
using Bytes = std::vector<uint8_t>;

static void check(bool ok, const std::string& why) { if (!ok) throw std::runtime_error(why); }
static uint16_t rd16(const Bytes& d, size_t p) { check(p <= d.size() && d.size()-p >= 2, "Truncated PE data"); return uint16_t(d[p]) | (uint16_t(d[p+1])<<8); }
static uint32_t rd32(const Bytes& d, size_t p) { check(p <= d.size() && d.size()-p >= 4, "Truncated PE data"); return uint32_t(d[p]) | uint32_t(d[p+1])<<8 | uint32_t(d[p+2])<<16 | uint32_t(d[p+3])<<24; }
static void wr32(Bytes& d, size_t p, uint32_t v) { check(p <= d.size() && d.size()-p >= 4, "Write out of bounds"); for(int i=0;i<4;i++) d[p+i]=uint8_t(v>>(8*i)); }
static Bytes read_file(const fs::path& p) { std::ifstream f(p,std::ios::binary); check(bool(f),"Cannot open source"); return Bytes(std::istreambuf_iterator<char>(f),{}); }
static void write_file(const fs::path& p,const Bytes& d) { std::ofstream f(p,std::ios::binary|std::ios::trunc); check(bool(f),"Cannot create output"); f.write(reinterpret_cast<const char*>(d.data()), std::streamsize(d.size())); f.flush(); check(bool(f),"Cannot write output"); }
static Bytes from_b64(const char* s) {
    Bytes out; uint32_t bits=0; int count=0;
    for (;*s;s++) { char c=*s; if(c=='=')break; int v;
        if(c>='A'&&c<='Z')v=c-'A'; else if(c>='a'&&c<='z')v=c-'a'+26;
        else if(c>='0'&&c<='9')v=c-'0'+52; else if(c=='+')v=62; else if(c=='/')v=63;
        else throw std::runtime_error("Invalid embedded payload encoding");
        bits=(bits<<6)|unsigned(v); count+=6; if(count>=8){count-=8;out.push_back(uint8_t(bits>>count));bits&=(1U<<count)-1;}
    } return out;
}
struct Section { size_t header; uint32_t va, vs, raw, rawsize; };
static Section find_section(const Bytes& d,size_t pe,const char* name) {
    uint16_t n=rd16(d,pe+6); check(n>0 && n<96,"Invalid section count");
    size_t first=pe+24+rd16(d,pe+20);
    check(first<=d.size() && d.size()-first>=size_t(n)*40,"Invalid section table");
    for(int i=0;i<n;i++){size_t h=first+i*40; char name8[9]{};std::memcpy(name8,d.data()+h,8);
        if(std::strcmp(name8,name)==0) {Section s{h,rd32(d,h+12),rd32(d,h+8),rd32(d,h+20),rd32(d,h+16)};
            check(s.raw<=d.size() && s.rawsize<=d.size()-s.raw,"Invalid section bounds");
            return s;
        }
    } throw std::runtime_error(std::string("Required PE section missing: ")+name);
}
static void verify_server2022(const Bytes& d,const Section& rs) {
    int matches=0;
    for(size_t p=rs.raw;p+28<=rs.raw+rs.rawsize;p++) {
        if(rd32(d,p)!=0xfeef04bdU)continue;
        uint32_t ms=rd32(d,p+8),ls=rd32(d,p+12);
        if(ms==0x000a0000U && (ls>>16)==20348U) {
            std::cout << "FixedFileVersion 10.0.20348."<<(ls&65535U)<<"\n"; matches++;
        }
    }
    check(matches==1,"Not a recognized Windows Server 2022 20348 DLL");
}
static bool is_target(const Bytes& d,size_t p) {
    static const uint8_t prefix[]={0x48,0x89,0x5c,0x24,0x08,0x57,0x48,0x83,0xec,0x20,0x48,0x8b,0x01,0x48,0x8b,0xda,0x48,0x8d,0x15};
    static const uint8_t suffix[]={0x48,0x8b,0xf9,0x48,0x85,0xc0,0x74,0x09,0x4c,0x8b,0x48,0x10,0x8b,0x48,0x04,0xeb,0x05,0x4c,0x8b,0xca,0x33,0xc9,0x48,0x8b,0x03,0x48,0x85,0xc0};
    return p+23+sizeof(suffix)<=d.size() && std::memcmp(d.data()+p,prefix,sizeof(prefix))==0 && std::memcmp(d.data()+p+23,suffix,sizeof(suffix))==0;
}
static uint32_t checksum(const Bytes& d,size_t omit) {
    uint64_t sum=0;
    for(size_t i=0;i<d.size();i+=2){if(i==omit || i==omit+2)continue;
        uint32_t v=d[i]|uint32_t(i+1<d.size()?d[i+1]:0)<<8;
        sum+=v;sum=(sum&65535U)+(sum>>16);
    } sum=(sum&65535U)+(sum>>16);sum=(sum&65535U)+(sum>>16);
    return uint32_t((sum+d.size())&0xffffffffU);
}
static Bytes patch(const Bytes& original) {
    Bytes d=original;
    check(d.size()>1024 && rd16(d,0)==0x5a4d,"Missing DOS header");
    size_t pe=rd32(d,0x3c);
    check(pe<d.size() && d.size()-pe>=24 && rd32(d,pe)==0x4550,"Missing PE header");
    check(rd16(d,pe+4)==0x8664 && rd16(d,pe+24)==0x20b,"Only AMD64 PE32+ DLL supported");
    check((rd16(d,pe+22)&0x2000)!=0,"Not a DLL");
    const Section text=find_section(d,pe,".text"),rs=find_section(d,pe,".rsrc");
    verify_server2022(d,rs);
    check(text.vs<=text.rawsize,"Text virtual size exceeds on-disk size");
    std::vector<uint32_t> hits;
    for(uint32_t j=0;j+60<text.vs;j++){size_t p=size_t(text.raw)+j;if(is_target(d,p))hits.push_back(j);}
    check(hits.size()==1,"Platform comparison helper not uniquely recognized; no modifications performed");
    uint32_t entry_rva=text.va+hits[0];size_t entry_file=text.raw+hits[0];
    // Confirm that the helper is used in a platform-filtering boolean loop.
    bool has_caller=false;
    for(uint32_t i=6;i+8<text.vs;i++){size_t p=text.raw+i;
        if(d[p]!=0xe8 || d[p+5]!=0x84 || d[p+6]!=0xc0 || d[p+7]!=0x74)continue;
        int64_t dest=int64_t(text.va)+i+5+int32_t(rd32(d,p+1));
        if(dest==entry_rva && std::memcmp(d.data()+p-6,"\x48\x8b\x17\x49\x8b\xcc",6)==0)has_caller=true;
    }
    check(has_caller,"Platform helper caller was not identified; no modifications performed");
    Bytes tramp=from_b64(kPayloadBase64);
    check(tramp.size()==1142,"Embedded payload size mismatch");
    static const uint8_t tail[]={0x48,0x89,0x5c,0x24,0x08,0xe9};
    check(std::memcmp(tramp.data()+tramp.size()-10,tail,sizeof(tail))==0,"Embedded trampoline footer invalid");
    // Prefer validated padding. If absent, append new executable section.
    uint32_t offset=(text.vs+3U)&~3U;
    const uint32_t reserve=uint32_t(tramp.size()+206);
    if(text.rawsize>=reserve && text.rawsize-reserve>offset) offset=(text.rawsize-reserve+3U)&~3U;
    bool cave_ok=(uint64_t(offset)+tramp.size()<=text.rawsize);
    if(cave_ok) for(size_t i=0;i<tramp.size();i++) if(d[text.raw+offset+i]!=0){cave_ok=false;break;}
    size_t cave_file=0;
    uint32_t cave_rva=0;
    if(cave_ok) {
        cave_file=text.raw+offset;cave_rva=text.va+offset;
    } else {
        uint32_t sectAlign=rd32(d,pe+24+32),fileAlign=rd32(d,pe+24+36);
        auto align=[](uint64_t x,uint32_t a)->uint32_t {
            check(a!=0 && (a&(a-1))==0 && x+uint64_t(a)-1<UINT32_MAX,"Invalid alignment");
            return uint32_t((x+a-1)&~uint64_t(a-1));
        };
        check(sectAlign>=fileAlign && fileAlign>=512,"Unsupported PE section alignment");
        uint16_t count=rd16(d,pe+6),optsize=rd16(d,pe+20);
        size_t headers=pe+24+optsize;
        uint32_t sizeHeaders=rd32(d,pe+24+60);
        check(headers+uint64_t(count+1)*40<=sizeHeaders && sizeHeaders<=d.size(),"No room for additional PE section header");
        size_t hdr=headers+uint64_t(count)*40;
        for(size_t i=0;i<40;i++) check(d[hdr+i]==0,"Section header gap is not empty");
        uint64_t maxRaw=0,maxVirt=0;
        for(uint16_t i=0;i<count;i++) {
            size_t h=headers+uint64_t(i)*40;
            uint32_t va=rd32(d,h+12),vs=rd32(d,h+8),raw=rd32(d,h+20),rawsize=rd32(d,h+16);
            check(uint64_t(raw)+rawsize<=d.size(),"Invalid section extent");
            maxRaw=std::max(maxRaw,uint64_t(raw)+rawsize);
            maxVirt=std::max(maxVirt,uint64_t(va)+std::max(vs,rawsize));
        }
        check(maxRaw==d.size(),"Existing file overlay prevents safe section append");
        check(rd32(d,pe+24+112+4*8)==0 && rd32(d,pe+24+112+4*8+4)==0,"Signed certificate overlay requires separate handling");
        uint32_t rawNew=align(maxRaw,fileAlign),virtNew=align(maxVirt,sectAlign);
        uint32_t rawLen=align(tramp.size(),fileAlign),virtSize=uint32_t(tramp.size());
        uint32_t imageSize=align(uint64_t(virtNew)+virtSize,sectAlign);
        check(uint64_t(rawNew)+rawLen<=SIZE_MAX,"New section size overflow");
        d.resize(size_t(rawNew)+rawLen,0);
        const char name[8]={'.','e','q','p','l','a','t',0};
        std::memcpy(d.data()+hdr,name,8);
        wr32(d,hdr+8,virtSize);wr32(d,hdr+12,virtNew);
        wr32(d,hdr+16,rawLen);wr32(d,hdr+20,rawNew);
        wr32(d,hdr+36,0x60000020U);
        check(count<65535,"Too many sections");
        d[pe+6]=uint8_t(count+1);d[pe+7]=uint8_t((count+1)>>8);
        wr32(d,pe+24+56,imageSize);
        wr32(d,pe+24+4,rd32(d,pe+24+4)+rawLen);
        cave_file=rawNew;cave_rva=virtNew;
        std::cout<<"Added executable .eqplat section for trampoline\n";
    }
    auto rel32=[](int64_t to,int64_t from)->int32_t{int64_t delta=to-from;
        check(delta>=INT32_MIN && delta<=INT32_MAX,"Jump out of 32-bit range");return int32_t(delta);};
    // Tail jump resumes exactly after the five original prologue bytes.
    wr32(tramp,tramp.size()-4,uint32_t(rel32(int64_t(entry_rva)+5,int64_t(cave_rva)+tramp.size())));
    std::copy(tramp.begin(),tramp.end(),d.begin()+cave_file);
    d[entry_file]=0xe9;wr32(d,entry_file+1,uint32_t(rel32(cave_rva,int64_t(entry_rva)+5)));
    if(cave_ok) wr32(d,text.header+8,uint32_t(text.rawsize));
    size_t sumoff=pe+24+64;wr32(d,sumoff,0);wr32(d,sumoff,checksum(d,sumoff));
    check(cave_ok ? d.size()==original.size() : d.size()>original.size(),"Unexpected output size");
    std::cout<<"Helper RVA 0x"<<std::hex<<entry_rva<<"; trampoline RVA 0x"<<cave_rva<<std::dec<<"\n";
    return d;
}
#ifdef _WIN32
int wmain(int argc,wchar_t** argv) {
#else
int main(int argc,char** argv) {
#endif
    try {
        // Help is independent from DLL parsing; no filesystem writes.
        if (argc==2) {
#ifdef _WIN32
            std::wstring a(argv[1]);
            if(a==L"-?" || a==L"/?" || a==L"-h" || a==L"--help") {
#else
            std::string a(argv[1]);
            if(a=="-?" || a=="/?" || a=="-h" || a=="--help") {
#endif
                std::cout << "InstallServicePatcher x64 - offline DLL patcher\n"
                    << "Usage:\n"
                    << "  InstallServicePatcher.exe <path-to-DLL>\n"
                    << "  InstallServicePatcher.exe <path-to-DLL> --restore\n"
                    << "  InstallServicePatcher.exe -?  (also /?, -h, --help)\\n\n"
                    << "Changes a writable offline DLL and creates <DLL>.original.bak.\n"
                    << "--restore restores from the backup (which is retained).\n"
                    << "Unsupported builds are rejected. Modified Microsoft DLLs\n"
                    << "may fail code integrity checks; use isolated test VMs.\n";
                return 0;
            }
        }
        check(argc>=2 && argc<=3,"Usage: InstallServicePatcher.exe <path-to-DLL> [--restore]");
        fs::path path(argv[1]);
        check(fs::exists(path) && fs::is_regular_file(path) && !fs::is_symlink(path),"Input must be an existing regular file, not a symlink");
        fs::path backup=path;backup+=L".original.bak";
        fs::path temp=path;temp+=L".patchtmp";
        check(!fs::exists(temp),"Temporary file already exists; no modifications performed");
        bool restore=false;
        if(argc==3) {
#ifdef _WIN32
            check(std::wstring(argv[2])==L"--restore","Unknown option");
#else
            check(std::string(argv[2])=="--restore","Unknown option");
#endif
            restore=true;
        }
        if(restore) {
            check(fs::is_regular_file(backup),"No original backup to restore");
            Bytes b=read_file(backup);write_file(temp,b);
            check(read_file(temp)==b,"Restore verification failed");
            fs::rename(temp,path);std::cout<<"Restored from backup; backup retained\n";return 0;
        }
        check(!fs::exists(backup),"Original backup already exists; refusing to overwrite it");
        Bytes original=read_file(path);Bytes changed=patch(original);
        // First validate transformations in memory. Never modify the original on a parse failure.
        fs::copy_file(path,backup,fs::copy_options::none);
        check(read_file(backup)==original,"Backup verification failed; original not modified");
        write_file(temp,changed);
        check(read_file(temp)==changed,"Written file verification failed; original not modified");
        fs::rename(temp,path);
        std::cout<<"PATCHED: "<<path.string()<<"\nBackup: "<<backup.string()<<"\n";
        return 0;
    } catch (const std::exception& e) {std::cerr<<"ERROR: "<<e.what()<<"\n";return 1;}
}
