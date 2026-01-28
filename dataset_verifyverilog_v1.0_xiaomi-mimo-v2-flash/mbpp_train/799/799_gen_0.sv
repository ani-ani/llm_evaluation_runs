module left_rotate_32bit (
    input clk,
    input rst_n,
    input start,
    input [31:0] num_in,
    input [4:0] d_in,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [31:0] num_reg;
    reg [4:0] d_reg;
    reg [31:0] temp_result;
    
    // Combinational rotation logic
    wire [31:0] left_shift;
    wire [31:0] right_shift;
    wire [31:0] rotation_result;
    
    assign left_shift = num_reg << d_reg;
    assign right_shift = num_reg >> (32 - d_reg);
    assign rotation_result = left_shift | right_shift;
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            num_reg <= 32'd0;
            d_reg <= 5'd0;
            temp_result <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        num_reg <= num_in;
                        d_reg <= d_in;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Calculate rotation
                    if (d_reg == 5'd0) begin
                        temp_result <= num_reg;
                    end else begin
                        temp_result <= rotation_result;
                    end
                    state <= FINISH;
                end
                
                FINISH: begin
                    result <= temp_result;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule