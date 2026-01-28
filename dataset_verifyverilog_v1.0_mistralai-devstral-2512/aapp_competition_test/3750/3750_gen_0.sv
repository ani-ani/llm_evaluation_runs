module table_tennis(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] k,
    input wire [31:0] a,
    input wire [31:0] b,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10;

    // Intermediate signals
    reg [31:0] sets_a;
    reg [31:0] sets_b;
    reg [31:0] remainder_a;
    reg [31:0] remainder_b;
    reg impossible;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            sets_a <= 32'd0;
            sets_b <= 32'd0;
            remainder_a <= 32'd0;
            remainder_b <= 32'd0;
            impossible <= 1'b0;
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
                    
                    // Calculate sets and remainders
                    sets_a <= a / k;
                    remainder_a <= a % k;
                    sets_b <= b / k;
                    remainder_b <= b % k;
                    
                    // Check for impossible conditions
                    impossible <= ((sets_a == 32'd0) && (remainder_a != 32'd0)) || 
                                 ((sets_b == 32'd0) && (remainder_b != 32'd0));
                    
                    // Compute result
                    if (impossible) begin
                        result <= 32'hFFFFFFFF;  // -1
                    end else begin
                        result <= sets_a + sets_b;
                    end
                    
                    // Move to finish state
                    state <= FINISH;
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