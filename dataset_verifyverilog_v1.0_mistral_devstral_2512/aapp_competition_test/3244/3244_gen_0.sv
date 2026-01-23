module reconstruct (
    input clk,
    input rst_n,
    input start,
    input [7:0] B0, B1, B2, B3,
    output reg [15:0] A0, A1, A2, A3,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Intermediate calculations
    wire signed [15:0] A0_temp;
    wire signed [15:0] A1_temp;
    wire signed [15:0] A2_temp;
    wire signed [15:0] A3_temp;

    // Compute A0 = (B0 + B1 + B3 - 2*B2) / 3
    assign A0_temp = ({1'b0, B0} + {1'b0, B1} + {1'b0, B3} - ({1'b0, B2} << 1)) / 3;
    
    // Compute A1 = (B0 + B1 - B2) - 2*A0
    assign A1_temp = ({1'b0, B0} + {1'b0, B1} - {1'b0, B2}) - (A0_temp << 1);
    
    // Compute A2 = B1 - A0 - A1
    assign A2_temp = {1'b0, B1} - A0_temp - A1_temp;
    
    // Compute A3 = B2 - A1 - A2
    assign A3_temp = {1'b0, B2} - A1_temp - A2_temp;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            A0 <= 16'd0;
            A1 <= 16'd0;
            A2 <= 16'd0;
            A3 <= 16'd0;
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
                    
                    // Perform calculations
                    A0 <= A0_temp;
                    A1 <= A1_temp;
                    A2 <= A2_temp;
                    A3 <= A3_temp;
                    
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