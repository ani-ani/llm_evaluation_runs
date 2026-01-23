module kernel_area (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] n,
    input wire signed [31:0] x [0:7],
    input wire signed [31:0] y [0:7],
    output reg [63:0] area,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Combinational calculation of sum of cross products
    reg signed [63:0] sum_comb;
    integer i;
    always @(*) begin
        sum_comb = 64'd0;
        for (i = 0; i < 8; i = i + 1) begin
            if (i < n) begin
                if (i < n-1) begin
                    sum_comb = sum_comb + (x[i] * y[i+1] - x[i+1] * y[i]);
                end else begin
                    sum_comb = sum_comb + (x[i] * y[0] - x[0] * y[i]);
                end
            end
        end
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            area <= 64'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
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
                    
                    // Compute absolute value and divide by 2
                    if (sum_comb < 0)
                        area <= (-sum_comb) >> 1;
                    else
                        area <= sum_comb >> 1;
                    
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