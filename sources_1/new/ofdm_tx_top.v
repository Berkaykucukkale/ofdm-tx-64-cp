`timescale 1ns / 1ps

module ofdm_tx_top(
    input wire clk,             
    input wire rst_n,           
    
    input wire [31:0] s_axis_data_tdata,   
    input wire s_axis_data_tvalid,         
    output wire s_axis_data_tready,        
    input wire s_axis_data_tlast,          
    
    output wire [31:0] m_axis_data_tdata,  
    output wire m_axis_data_tvalid,        
    input wire m_axis_data_tready,         
    output wire m_axis_data_tlast          
);

    // --- IFFT KONFİGÜRASYON SİNYALLERİ ---
    wire [15:0] config_tdata;  
    reg config_tvalid;
    wire config_tready;
    reg config_sent; // Makine ayarlandı bayrağı

    assign config_tdata = 16'b00000000_00000000; 

    // Akıllı Tetikleyici
    always @(posedge clk) begin
        if (!rst_n) begin
            config_tvalid <= 1'b0; 
            config_sent <= 1'b0;
        end else begin
            if (!config_sent) begin
                config_tvalid <= 1'b1; 
                if (config_tready == 1'b1 && config_tvalid == 1'b1) begin
                    config_tvalid <= 1'b0; 
                    config_sent <= 1'b1;   
                end
            end
        end
    end

    // =========================================================
    // 🔥 DONANIMSAL VERİ KİLİDİ (DATA GATE) - ÇÖZÜM NOKTASI
    // =========================================================
    wire internal_data_tready;
    
    wire internal_data_tvalid = (config_sent == 1'b1) ? s_axis_data_tvalid : 1'b0;
    assign s_axis_data_tready = (config_sent == 1'b1) ? internal_data_tready : 1'b0;


    // =========================================================
    // 🌉 ARA BAĞLANTI SİNYALLERİ (IFFT Çıkışı -> CP Adder Girişi)
    // =========================================================
    wire [31:0] ifft_out_tdata;
    wire        ifft_out_tvalid;
    wire        ifft_out_tready;
    wire        ifft_out_tlast;


    // --- XILINX FFT IP ÇEKİRDEĞİNİN ÇAĞRILMASI ---
    xfft_0 ifft_block (
      .aclk(clk),
      .aresetn(rst_n),  
      
      .s_axis_config_tdata(config_tdata),                        
      .s_axis_config_tvalid(config_tvalid),                      
      .s_axis_config_tready(config_tready),                      
      
      .s_axis_data_tdata(s_axis_data_tdata),                     
      .s_axis_data_tvalid(internal_data_tvalid), 
      .s_axis_data_tready(internal_data_tready), 
      .s_axis_data_tlast(s_axis_data_tlast),                     
      
      // Çıkışları artık doğrudan dışarıya değil, ara kablolara veriyoruz!
      .m_axis_data_tdata(ifft_out_tdata),                        
      .m_axis_data_tvalid(ifft_out_tvalid),                      
      .m_axis_data_tready(ifft_out_tready),                      
      .m_axis_data_tlast(ifft_out_tlast),                        
      
      .event_frame_started(),                 
      .event_tlast_unexpected(),           
      .event_tlast_missing(),                 
      .event_status_channel_halt(),     
      .event_data_in_channel_halt(),   
      .event_data_out_channel_halt()  
    );

    // =========================================================
    // --- CYCLIC PREFIX EKLEME MODÜLÜNÜN ÇAĞRILMASI ---
    // =========================================================
    cp_adder #(
        .N(64),
        .CP_LEN(16)
    ) cp_inst (
        .clk(clk),
        .rst_n(rst_n),

        // Girişler IFFT'den gelen ara kablolar
        .s_axis_tdata(ifft_out_tdata),
        .s_axis_tvalid(ifft_out_tvalid),
        .s_axis_tready(ifft_out_tready),
        .s_axis_tlast(ifft_out_tlast),

        // Çıkışlar doğrudan ofdm_tx_top modülünün ana çıkışları
        .m_axis_tdata(m_axis_data_tdata),
        .m_axis_tvalid(m_axis_data_tvalid),
        .m_axis_tready(m_axis_data_tready),
        .m_axis_tlast(m_axis_data_tlast)
    );

endmodule