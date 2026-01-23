module binary_seq_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n_in,
    output reg [15:0] result,
    output reg done
);

    // Parameters
    localparam [3:0] MAX_N = 4'd8;
    localparam [3:0] DATA_WIDTH = 4'd16;
    localparam [3:0] N_WIDTH = 4'd4;
    localparam [3:0] INT_WIDTH = 5'd32;

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALC = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // Registers
    reg [1:0] state;
    reg [3:0] n_reg;
    reg [3:0] r_reg;
    reg [31:0] nCr_reg;
    reg [31:0] res_reg;
    reg [7:0] cycle_count;
    reg done_internal;

    // Combinational signals
    reg [31:0] next_nCr;
    reg [31:0] next_res;
    reg [3:0] next_r;

    // Counter limit for timeout prevention
    localparam [7:0] MAX_CYCLES = 8'd50;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers on reset
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            n_reg <= 4'd0;
            r_reg <= 4'd0;
            nCr_reg <= 32'd0;
            res_reg <= 32'd0;
            cycle_count <= 8'd0;
            done_internal <= 1'b0;
        end else begin
            // Default values
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    done_internal <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start && (n_in >= 4'd1) && (n_in <= MAX_N)) begin
                        n_reg <= n_in;
                        r_reg <= 4'd1;
                        nCr_reg <= 32'd1;      // nCr = 1 (for r=0)
                        res_reg <= 32'd1;      // res = 1 (nCr^2 for r=0)
                        state <= CALC;
                    end
                end

                CALC: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute nCr for current r
                    // nCr = nCr * (n + 1 - r) / r
                    // (n + 1 - r) = (n_reg + 4'd1) - r_reg
                    if (r_reg <= n_reg) begin
                        nCr_reg <= next_nCr;
                        res_reg <= next_res;
                        r_reg <= next_r;
                    end else begin
                        // Done with calculation
                        result <= res_reg[15:0];
                        done_internal <= 1'b1;
                        state <= DONE;
                    end

                    // Timeout protection
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IDLE;
                    end
                end

                DONE: begin
                    done <= 1'b1;  // Assert done for 1 cycle
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Combinational computation logic
    always @(*) begin
        // Calculate nCr = nCr * (n + 1 - r) / r
        // All intermediate values fit in 32-bit for n <= 8
        reg [31:0] numerator;
        reg [31:0] division_temp;
        
        numerator = (n_reg + 32'd1) - r_reg;
        division_temp = nCr_reg * numerator;
        next_nCr = division_temp / r_reg;
        
        // Update result: res = res + nCr^2
        next_res = res_reg + (next_nCr * next_nCr);
        
        // Increment r
        next_r = r_reg + 4'd1;
    end

endmodule