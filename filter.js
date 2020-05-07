/**
 * 引入java类
 */
var Base64 = Java.type('java.util.Base64');
var String = Java.type('java.lang.String');
var File = Java.type('java.io.File');
var BufferedInputStream = Java.type('java.io.BufferedInputStream');
var FileInputStream = Java.type('java.io.FileInputStream');
var ByteArray = Java.type("byte[]");
 
 
/**
 * common 通用变量
 */
//浆站文件存储根路径
var rootPath = '/Users/nnnmar/Downloads/';
 
//浆站orgId
var orgId = '49e0dde38d494477a9bb7d1910584a53';
 
//图片剥离过滤配置： 数据库->数据库表->需转换字段数组
var output_byte_convert = {
        // jytc_xypt:{
        //         t_bp_provider_accessory:['ACCESSORY_IMG']
        //     }
    };
 
//数据处理
function process_row(row) {
 
    //JSON根添加orgId属性
    row.extra_attributes['orgId'] = orgId;
 
    /**
     * 本次过滤需求是：同步数据库至省平台，本地数据库表中存储的是文件路径，
     * 故需把文件路径字段的值设置为文件数据而二进制base64 编码字符串；
     */
    //只有插入和更新的数据才进行转换
    if(('update' == row.type
            || 'insert' == row.type
            || 'bootstrap-insert' == row.type) && row.data ){
 
        //数据库有转换
        var database = output_byte_convert[row.database];
        if(database){
            //需要转换的字段
            var fields = database[row.table];
            if(fields && fields.length > 0){
                for(var i=0,j=fields.length;i<j;i++){
                    var field = fields[i];
 
                    if('update' == row.type && !row.old_data[field]){
                        continue;
                    }
 
                    var val = row.data[fields[i]];
                    if(val){
                        var bytes = Base64.getDecoder().decode(String.valueOf(val));
                        var path = new String(bytes,"UTF-8");
 
                        var bis = null;
                        try {
                            var file = new File(rootPath + path);
                            if(file.exists()){
                                bis = new BufferedInputStream( new FileInputStream(file));
                                var dataBytes = new ByteArray(file.length());
                                bis.read(dataBytes);
                                if(dataBytes){
                                    //文件二进制数据转换为base64 编码
                                    row.data.put(fields[i],Base64.getEncoder().encodeToString(dataBytes));
                                }
                            }else {
                                print("File does not exist...");
                            }
                        }catch(err){
                            print(err.message);
                        }finally {
                            if(bis){
                                try {
                                    bis.close;
                                }catch(e){
                                    print(e.message);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}