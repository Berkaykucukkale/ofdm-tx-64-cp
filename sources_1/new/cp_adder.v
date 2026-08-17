`timescale 1ns / 1ps

module cp_adder #(
    parameter N = 64,         // IFFT'den gelen toplam veri sayısı
    parameter CP_LEN = 16     // Eklenecek Cyclic Prefix uzunluğu
)(
    input wire clk,
    input wire rst_n,

    // --- IFFT'den Gelen Giriş Hattı (Slave AXI-Stream) ---
    input wire [31:0]  s_axis_tdata,
    input wire         s_axis_tvalid,
    output reg         s_axis_tready,
    input wire         s_axis_tlast,

    // --- Dışarı Çıkan Çıkış Hattı (Master AXI-Stream) ---
    output reg [31:0]  m_axis_tdata,
    output reg         m_axis_tvalid,
    input wire         m_axis_tready,
    output reg         m_axis_tlast
);

    // 64 veriyi tutacağımız geçici donanım hafızası (RAM)
    reg [31:0] buffer [0:N-1];
    
    // Hafızayı okuma ve yazma indeksleri
    reg [6:0] write_ptr;
    reg [6:0] read_ptr;

    // Durum Makinesi (State Machine) Aşamaları
    localparam IDLE      = 2'd0;
    localparam GATHER    = 2'd1;
    localparam SEND_CP   = 2'd2;
    localparam SEND_DATA = 2'd3;

    reg [1:0] state;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            s_axis_tready <= 1'b0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
            write_ptr <= 0;
            read_ptr  <= 0;
            m_axis_tdata <= 32'd0;
        end else begin
            case (state)
                
                // 1. BEKLEME AŞAMASI
                IDLE: begin
                    m_axis_tvalid <= 1'b0;
                    m_axis_tlast  <= 1'b0;
                    write_ptr     <= 0;
                    
                    if (s_axis_tvalid) begin
                        s_axis_tready <= 1'b1;
                        state <= GATHER;
                    end
                end

                // 2. IFFT'DEN VERİLERİ RAM'E KAYDETME AŞAMASI
                GATHER: begin
                    if (s_axis_tvalid && s_axis_tready) begin
                        buffer[write_ptr] <= s_axis_tdata;
                        write_ptr <= write_ptr + 1;
                        
                        if (write_ptr == N - 1 || s_axis_tlast) begin
                            s_axis_tready <= 1'b0;
                            read_ptr <= N - CP_LEN; 
                            state <= SEND_CP;
                        end
                    end
                end

                // 3. CYCLIC PREFIX GÖNDERME AŞAMASI (İndeks 48'den 63'e)
                SEND_CP: begin
                    m_axis_tvalid <= 1'b1;
                    m_axis_tdata  <= buffer[read_ptr];
                    
                    if (m_axis_tready && m_axis_tvalid) begin
                        if (read_ptr == N - 1) begin
                            read_ptr <= 0; 
                            state <= SEND_DATA;
                        end else begin
                            read_ptr <= read_ptr + 1;
                        end
                    end
                end

                // 4. ASIL VERİYİ GÖNDERME AŞAMASI (İndeks 0'dan 63'e)
                SEND_DATA: begin
                    m_axis_tvalid <= 1'b1;
                    m_axis_tdata  <= buffer[read_ptr];
                    
                    // Okuma işaretçisi son veriye geldiğinde TLAST bayrağını hazırlıyoruz
                    if (read_ptr == N - 1) begin
                        m_axis_tlast <= 1'b1;
                    end else begin
                        m_axis_tlast <= 1'b0;
                    end

                    if (m_axis_tready && m_axis_tvalid) begin
                        // Eğer o an çıkışta TLAST 1 ise, 80. son veri başarıyla teslim edilmiştir!
                        if (m_axis_tlast == 1'b1) begin
                            m_axis_tvalid <= 1'b0;
                            m_axis_tlast  <= 1'b0;
                            state <= IDLE;
                        end else begin
                            // Son veriye kadar işaretçiyi arttırmaya devam et
                            if (read_ptr < N - 1) begin
                                read_ptr <= read_ptr + 1;
                            end
                        end
                    end
                end
            endcase
        end
    end
endmodule