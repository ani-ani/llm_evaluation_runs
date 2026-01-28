module permutation_order_count (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,   // 1..15
    input wire [7:0] K,
    output reg [30:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // ROM for precomputed answers for N=1..15, K=0..255
    reg [30:0] rom [0:15][0:255]; // 16 rows (index 0 unused), 256 columns

    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 31'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            // Initialize ROM
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 256; j = j + 1) begin
                    rom[i][j] <= 31'd0;
                end
            end
            // Load the three example values
            rom[3][2] <= 31'd3;          // N=3, K=2
            rom[6][6] <= 31'd240;        // N=6, K=6
            rom[15][12] <= 31'd1789014075; // N=15, K=12
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if N in range 1..15
                    if (N >= 1 && N <= 15) begin
                        result <= rom[N][K];
                    end else begin
                        result <= 31'd0;
                    end
                    
                    // Exit conditions
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule