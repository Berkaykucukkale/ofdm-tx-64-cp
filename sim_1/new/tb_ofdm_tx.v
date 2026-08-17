`timescale 1ns / 1ps

module tb_ofdm_tx();

    // --- 1. SİNYAL TANIMLAMALARI ---
    reg clk;
    reg rst_n;
    
    reg [31:0] s_axis_data_tdata;
    reg s_axis_data_tvalid;
    wire s_axis_data_tready;
    reg s_axis_data_tlast;
    
    wire [31:0] m_axis_data_tdata;
    wire m_axis_data_tvalid;
    reg m_axis_data_tready;
    wire m_axis_data_tlast;

    integer i; 
    integer k;
    reg [31:0] bpsk_rom [0:63];

    // --- 2. UUT (Test Edilecek Modül) ---
    ofdm_tx_top uut (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_data_tdata(s_axis_data_tdata),
        .s_axis_data_tvalid(s_axis_data_tvalid),
        .s_axis_data_tready(s_axis_data_tready),
        .s_axis_data_tlast(s_axis_data_tlast),
        .m_axis_data_tdata(m_axis_data_tdata),
        .m_axis_data_tvalid(m_axis_data_tvalid),
        .m_axis_data_tready(m_axis_data_tready),
        .m_axis_data_tlast(m_axis_data_tlast)
    );

    // --- 3. SAAT SİNYALİ ÜRETİMİ ---
    always #5 clk = ~clk;

    // --- 4. SİMÜLASYON SENARYOSU ---
    initial begin
        
        // BPSK HAFIZASININ DOLDURULMASI
        for (k = 0; k < 64; k = k + 1) begin
            bpsk_rom[k] = 32'h0000_0000;
        end

        bpsk_rom[6]  = 32'h0000_0001; bpsk_rom[7]  = 32'h0000_FFFF; bpsk_rom[8]  = 32'h0000_0001; bpsk_rom[9]  = 32'h0000_FFFF; bpsk_rom[10] = 32'h0000_0001;
        bpsk_rom[11] = 32'h0000_0001; 
        bpsk_rom[12] = 32'h0000_FFFF; bpsk_rom[13] = 32'h0000_0001; bpsk_rom[14] = 32'h0000_FFFF; bpsk_rom[15] = 32'h0000_0001; bpsk_rom[16] = 32'h0000_FFFF;
        bpsk_rom[17] = 32'h0000_0001; bpsk_rom[18] = 32'h0000_FFFF; bpsk_rom[19] = 32'h0000_0001; bpsk_rom[20] = 32'h0000_FFFF; bpsk_rom[21] = 32'h0000_0001;
        bpsk_rom[22] = 32'h0000_FFFF; bpsk_rom[23] = 32'h0000_0001; bpsk_rom[24] = 32'h0000_FFFF;
        bpsk_rom[25] = 32'h0000_0001; 
        bpsk_rom[26] = 32'h0000_FFFF; bpsk_rom[27] = 32'h0000_0001; bpsk_rom[28] = 32'h0000_FFFF; bpsk_rom[29] = 32'h0000_0001; bpsk_rom[30] = 32'h0000_FFFF; bpsk_rom[31] = 32'h0000_0001;
        
        bpsk_rom[33] = 32'h0000_FFFF; bpsk_rom[34] = 32'h0000_0001; bpsk_rom[35] = 32'h0000_FFFF; bpsk_rom[36] = 32'h0000_0001; bpsk_rom[37] = 32'h0000_FFFF; bpsk_rom[38] = 32'h0000_0001;
        bpsk_rom[39] = 32'h0000_0001; 
        bpsk_rom[40] = 32'h0000_FFFF; bpsk_rom[41] = 32'h0000_0001; bpsk_rom[42] = 32'h0000_FFFF; bpsk_rom[43] = 32'h0000_0001; bpsk_rom[44] = 32'h0000_FFFF;
        bpsk_rom[45] = 32'h0000_0001; bpsk_rom[46] = 32'h0000_FFFF; bpsk_rom[47] = 32'h0000_0001; bpsk_rom[48] = 32'h0000_FFFF; bpsk_rom[49] = 32'h0000_0001;
        bpsk_rom[50] = 32'h0000_FFFF; bpsk_rom[51] = 32'h0000_0001; bpsk_rom[52] = 32'h0000_FFFF;
        bpsk_rom[53] = 32'h0000_FFFF; 
        bpsk_rom[54] = 32'h0000_FFFF; bpsk_rom[55] = 32'h0000_0001; bpsk_rom[56] = 32'h0000_FFFF; bpsk_rom[57] = 32'h0000_0001; bpsk_rom[58] = 32'h0000_FFFF;

        // BAŞLANGIÇ VE RESET
        clk = 0;
        rst_n = 0;
        s_axis_data_tdata = 0;
        s_axis_data_tvalid = 0;
        s_axis_data_tlast = 0;
        m_axis_data_tready = 1; 
        
        // Reset'i 100 ns yapıyoruz ki devasa IFFT makinesi iç RAM'lerini rahatça temizlesin
        #100;
        rst_n = 1;
        #100;

        // VERİ GÖNDERME DÖNGÜSÜ
        for (i = 0; i < 64; i = i + 1) begin
            
            // 🔥 YARIŞ DURUMU ÇÖZÜMÜ: Sinyalleri sadece saatin DÜŞEN kenarında değiştir!
            @(negedge clk); 
            
            s_axis_data_tvalid = 1;
            s_axis_data_tdata = bpsk_rom[i]; 

            if (i == 63) begin
                s_axis_data_tlast = 1;
            end else begin
                s_axis_data_tlast = 0;
            end

            // IFFT veriyi alana kadar bekle, ama beklemeyi de düşen kenarda yap
            while (s_axis_data_tready == 1'b0) begin
                @(negedge clk);
            end
        end

        // Aktarım bitti, hatları temizle
        @(negedge clk);
        s_axis_data_tvalid = 0;
        s_axis_data_tlast = 0;
        s_axis_data_tdata = 0;

        // IFFT hesabının bitmesi için 20 mikrosaniye bekle
        #20000;
        
        $finish;
    end

endmodule