public class RunShell {  
    public static void main(String[] args){  
        try {  
            String shpath="/root/huaiyu/fileDetect.sh";  
            Process ps = Runtime.getRuntime().exec(shpath);  
            ps.waitFor();    
            System.out.println("Intel: file logged...");  
            }   
        catch (Exception e) {  
            e.printStackTrace();  
            }  
    }  
}  
