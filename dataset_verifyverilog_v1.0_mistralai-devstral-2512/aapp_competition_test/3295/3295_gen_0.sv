module mirko_slavko_happy_numbers(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] k_in,
    input wire [7:0] l_in,
    input wire [7:0] m_in,
    output reg [23:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] SEARCH  = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state, next_state;
    
    // Input registers
    reg [7:0] k_reg, l_reg, m_reg;
    
    // Search variables
    reg [15:0] start_num;
    reg [15:0] end_num;
    reg [15:0] happy_count;
    reg [15:0] h_end, h_start_minus;
    reg [15:0] max_start;
    
    // Prime ROM (10,000 bits = 1250 bytes)
    reg [7:0] prime_rom [0:1249];
    
    // Happy prefix sum ROM (10,001 entries, 16-bit each)
    reg [15:0] H_rom [0:10000];
    
    // Initialize prime ROM (simplified - in real implementation, this would be pre-calculated)
    integer i, j;
    initial begin
        // Initialize all to 1 (assume prime)
        for (i = 0; i < 1250; i = i + 1) begin
            prime_rom[i] = 8'hFF;
        end
        
        // Mark 0 and 1 as non-prime
        prime_rom[0] = 8'hFE;  // bit 0 = 0, bit 1 = 0
        
        // Sieve of Eratosthenes (simplified for synthesis)
        // In real implementation, this would be pre-computed
        for (i = 2; i * i <= 10000; i = i + 1) begin
            if (prime_rom[i/8][i%8]) begin
                for (j = i * i; j <= 10000; j = j + i) begin
                    prime_rom[j/8] = prime_rom[j/8] & ~(1 << (j%8));
                end
            end
        end
        
        // Initialize H_rom
        H_rom[0] = 16'd0;
        for (i = 1; i <= 10000; i = i + 1) begin
            H_rom[i] = H_rom[i-1];
            if ((i <= m_in) || (prime_rom[i/8][i%8])) begin
                H_rom[i] = H_rom[i] + 16'd1;
            end
        end
    end
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 24'd0;
            done <= 1'b0;
            start_num <= 16'd0;
            k_reg <= 8'd0;
            l_reg <= 8'd0;
            m_reg <= 8'd0;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SEARCH;
                end
            end
            
            SEARCH: begin
                if (start_num == max_start) begin
                    next_state = DONE_STATE;
                end else if (happy_count == l_reg) begin
                    next_state = DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already reset above
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        k_reg <= k_in;
                        l_reg <= l_in;
                        m_reg <= m_in;
                        start_num <= 16'd1;
                        max_start <= 16'd10000 - k_reg + 16'd1;
                    end
                end
                
                SEARCH: begin
                    end_num <= start_num + k_reg - 16'd1;
                    h_end <= H_rom[end_num];
                    h_start_minus <= H_rom[start_num - 16'd1];
                    happy_count <= h_end - h_start_minus;
                    
                    if (happy_count == l_reg) begin
                        result <= start_num;
                    end else if (start_num == max_start) begin
                        result <= 24'd255;  // -1 in 24-bit
                    end else begin
                        start_num <= start_num + 16'd1;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    done <= 1'b0;
                end
            endcase
        end
    end
    
    // Ensure done is only high for one cycle
    always @(posedge clk) begin
        if (state != DONE_STATE) begin
            done <= 1'b0;
        end
    end

endmodule