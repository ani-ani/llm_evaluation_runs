module cookie_distribution (
    input clk,
    input rst_n,
    input start,
    input [31:0] N,
    input [31:0] A,
    input [31:0] B,
    input [31:0] C,
    output reg [63:0] result,
    output reg done
);
    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Combinational wire declarations for intermediate values
    wire [63:0] A_ext = {32'd0, A};
    wire [63:0] B_ext = {32'd0, B};
    wire [63:0] C_ext = {32'd0, C};
    wire [63:0] N_ext = {32'd0, N};
    
    wire [63:0] T = A_ext + B_ext + C_ext;
    wire [63:0] M = (A_ext > B_ext) ? ((A_ext > C_ext) ? A_ext : C_ext) : ((B_ext > C_ext) ? B_ext : C_ext);
    wire [63:0] two_M = M << 1;
    wire [63:0] T_plus_N = T + N_ext;
    wire condition = (two_M <= T_plus_N);
    wire [63:0] part = T - M;
    wire [63:0] two_part = part << 1;
    wire [63:0] else_result = two_part + N_ext;
    wire [63:0] computed_result = condition ? T : else_result;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 64'd0;
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
                    result <= computed_result;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
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