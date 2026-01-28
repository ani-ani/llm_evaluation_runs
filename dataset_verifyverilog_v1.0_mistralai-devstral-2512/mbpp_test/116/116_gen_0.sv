module tuple_to_int(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] len,
    input wire [3:0] nums [0:3],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [3:0] index;
    reg [15:0] temp_result;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            index <= 4'd0;
            temp_result <= 16'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        index <= 4'd0;
                        temp_result <= 16'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Concatenate digits
                    if (index < len) begin
                        temp_result <= temp_result * 16'd10 + nums[index];
                        index <= index + 4'd1;
                    end
                    
                    // Exit conditions
                    if ((index >= len) || (cycle_count >= MAX_CYCLES)) begin
                        state <= FINISH;
                    end
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