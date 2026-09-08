#!/bin/bash
#=============================================================================
# YT9215S 瀹樻柟瀹屾暣鐗堥┍鍔ㄩ儴缃茶剼鏈?# 浠庢棫鍐呮牳鐩綍鎻愬彇瀹樻柟椹卞姩锛屼慨鏀?vermagic 鍚庨儴缃插埌褰撳墠鍐呮牳
# 鍖呭惈纭欢娴佸嵏杞姐€丵oS銆丏SA 楂樼骇鍔熻兘绛夊畬鏁寸壒鎬?#=============================================================================

set -e

#============================= 閰嶇疆鍖?======================================
# 瀹樻柟椹卞姩鎵€鍦ㄧ殑鏃у唴鏍哥増鏈紙绯荤粺鍗囩骇鍚庨€氬父浼氫繚鐣欙級
OFFICIAL_KERNEL="${OFFICIAL_KERNEL:-6.18.18.c951-trim}"
CURRENT_KERNEL="$(uname -r)"
DRIVER_DIR="/lib/modules/$(uname -r)/updates/trim/yt921x"
OFFICIAL_DIR="/lib/modules/$OFFICIAL_KERNEL/updates/trim/yt921x"
WORK_DIR="/tmp/yt921x_official_deploy"

# 棰滆壊杈撳嚭
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

#============================= 鍑芥暟鍖?======================================
print_step() {
    echo -e "\n${GREEN}[姝ラ $1]${NC} $2"
    echo "----------------------------------------------------------------"
}

print_error() {
    echo -e "\n${RED}[閿欒]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[淇℃伅]${NC} $1"
}

#============================= 涓绘祦绋?======================================

echo -e "${BLUE}"
echo "================================================================"
echo "  YT9215S 瀹樻柟瀹屾暣鐗堥┍鍔ㄩ儴缃茶剼鏈?
echo "  鍖呭惈纭欢娴佸嵏杞姐€丵oS銆丏SA 楂樼骇鍔熻兘"
echo "================================================================"
echo -e "${NC}"

# 姝ラ1: 妫€鏌ュ畼鏂归┍鍔ㄦ槸鍚﹀瓨鍦?print_step "1/7" "妫€鏌ュ畼鏂归┍鍔ㄦ簮鏂囦欢"
if [ ! -f "$OFFICIAL_DIR/yt921x.ko" ]; then
    print_error "鏈壘鍒板畼鏂归┍鍔? $OFFICIAL_DIR/yt921x.ko"
    echo "璇风‘璁ゆ棫鍐呮牳鐗堟湰鍙凤紝閫氳繃鐜鍙橀噺鎸囧畾:"
    echo "  OFFICIAL_KERNEL=6.18.18.cXXX-trim sudo bash $0"
    echo ""
    echo "鍙敤鐨勫唴鏍哥増鏈?"
    ls /lib/modules/ 2>/dev/null
    exit 1
fi

echo "瀹樻柟椹卞姩鐩綍: $OFFICIAL_DIR"
echo "yt921x.ko: $(stat -c%s $OFFICIAL_DIR/yt921x.ko) 瀛楄妭"
echo "tag_yt921x.ko: $(stat -c%s $OFFICIAL_DIR/tag_yt921x.ko) 瀛楄妭"

# 姝ラ2: 楠岃瘉瀹樻柟椹卞姩浣跨敤 0x9988 tag type
print_step "2/7" "楠岃瘉瀹樻柟椹卞姩 Tag EtherType"
if command -v objdump &> /dev/null; then
    TAG_TYPE=$(objdump -d "$OFFICIAL_DIR/yt921x.ko" 2>/dev/null | grep -o 'mov.*#0x9988' | head -1)
    if [ -n "$TAG_TYPE" ]; then
        print_info "纭瀹樻柟椹卞姩浣跨敤 0x9988锛堜笌纭欢榛樿鍊煎尮閰嶏級"
    else
        print_info "鏃犳硶鍙嶆眹缂栭獙璇侊紝璺宠繃"
    fi
else
    print_info "objdump 鏈畨瑁咃紝璺宠繃楠岃瘉"
fi

# 姝ラ3: 鍑嗗宸ヤ綔鐩綍
print_step "3/7" "鍑嗗宸ヤ綔鐩綍"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cp "$OFFICIAL_DIR/yt921x.ko" "$WORK_DIR/"
cp "$OFFICIAL_DIR/tag_yt921x.ko" "$WORK_DIR/"

# 姝ラ4: 淇敼 vermagic
print_step "4/7" "淇敼 vermagic 閫傞厤褰撳墠鍐呮牳"
echo "鏃у唴鏍? $OFFICIAL_KERNEL"
echo "鏂板唴鏍? $CURRENT_KERNEL"

sed -i "s/$OFFICIAL_KERNEL/$CURRENT_KERNEL/g" "$WORK_DIR/yt921x.ko"
sed -i "s/$OFFICIAL_KERNEL/$CURRENT_KERNEL/g" "$WORK_DIR/tag_yt921x.ko"

echo "淇敼鍚?"
strings "$WORK_DIR/yt921x.ko" | grep '^vermagic='
strings "$WORK_DIR/tag_yt921x.ko" | grep '^vermagic='

# 姝ラ5: 澶囦唤褰撳墠椹卞姩
print_step "5/7" "澶囦唤褰撳墠椹卞姩"
BACKUP_DIR="$DRIVER_DIR/backup_$(date +%Y%m%d%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp "$DRIVER_DIR/yt921x.ko" "$BACKUP_DIR/" 2>/dev/null || true
cp "$DRIVER_DIR/tag_yt921x.ko" "$BACKUP_DIR/" 2>/dev/null || true
echo "澶囦唤鍒? $BACKUP_DIR"

# 姝ラ6: 瀹夎椹卞姩
print_step "6/7" "瀹夎瀹樻柟瀹屾暣鐗堥┍鍔?
mkdir -p "$DRIVER_DIR"
cp "$WORK_DIR/yt921x.ko" "$DRIVER_DIR/"
cp "$WORK_DIR/tag_yt921x.ko" "$DRIVER_DIR/"
depmod -a 2>/dev/null || true

# 璁剧疆寮€鏈鸿嚜鍚?mkdir -p /etc/modules-load.d
cat > /etc/modules-load.d/yt921x.conf << 'EOF'
tag_yt921x
yt921x
EOF

echo "椹卞姩宸插畨瑁呭埌: $DRIVER_DIR"

# 姝ラ7: 閲嶆柊鍔犺浇骞堕獙璇?print_step "7/7" "閲嶆柊鍔犺浇椹卞姩骞堕獙璇?
rmmod yt921x 2>/dev/null || true
rmmod tag_yt921x 2>/dev/null || true
sleep 1
modprobe tag_yt921x 2>/dev/null || true
modprobe yt921x 2>/dev/null || true
sleep 3

echo ""
echo "=== 楠岃瘉缁撴灉 ==="
echo "椹卞姩妯″潡:"
lsmod | grep yt921 || echo -e "${RED}椹卞姩鏈姞杞?${NC}"

echo ""
echo "鐗╃悊缃戝彛鏁伴噺锛堝簲涓?2锛?"
ip -o link show | grep -vE 'lo:|br-|docker|veth' | wc -l

echo ""
echo "楂樼骇鍔熻兘绗﹀彿锛堝簲涓?9涓緷璧栵級:"
nm -u "$DRIVER_DIR/yt921x.ko" 2>/dev/null | wc -l

echo ""
echo "纭欢娴佸嵏杞芥敮鎸?"
nm -u "$DRIVER_DIR/yt921x.ko" 2>/dev/null | grep -c 'flow_rule_match' | xargs -I{} echo "  flow_rule_match_* 鍑芥暟: {} 涓?

echo ""
echo -e "${GREEN}================================================================"
echo "  瀹樻柟瀹屾暣鐗堥┍鍔ㄩ儴缃插畬鎴?"
echo "===============================================================${NC}"
echo "  椹卞姩澶у皬: $(stat -c%s $DRIVER_DIR/yt921x.ko) 瀛楄妭"
echo "  渚濊禆绗﹀彿: $(nm -u $DRIVER_DIR/yt921x.ko 2>/dev/null | wc -l) 涓?
echo "  澶囦唤鐩綍: $BACKUP_DIR"
echo ""
echo "  鍖呭惈鍔熻兘: 纭欢娴佸嵏杞?TC flower)銆丵oS/DSCP鏄犲皠銆丏SA楂樼骇鍔熻兘"
echo -e "${GREEN}===============================================================${NC}"
