module sum_range_fsm (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [3:0] m,
    input wire [3:0] n,
    output reg [15:0] result,
    output reg done
);

    // State encoding
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] current_index;
    reg [15:0] accumulator;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Select current array element
    wire [7:0] current_value;
    assign current_value = (current_index == 4'd0) ? arr_0 :
                          (current_index == 4'd1) ? arr_1 :
                          (current_index == 4'd2) ? arr_2 :
                          (current_index == 4'd3) ? arr_3 :
                          (current_index == 4'd4) ? arr_4 :
                          (current_index == 4'd5) ? arr_5 :
                          (current_index == 4'd6) ? arr_6 :
                          arr_7;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
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
                    next_state = COMPUTE;
                end
            end
            
            COMPUTE: begin
                if (current_index > n || cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Data path and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_index <= 4'd0;
            accumulator <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        current_index <= m;
                        accumulator <= 16'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (current_index <= n) begin
                        accumulator <= accumulator + current_value;
                        current_index <= current_index + 4'd1;
                    end
                    done <= 1'b0;
                end
                
                FINISH: begin
                    result <= accumulator;
                    done <= 1'b1;
                end
                
                default: begin
                    current_index <= 4'd0;
                    accumulator <= 16'd0;
                    result <= 16'd0;
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                end
            endcase
        end
    end

endmodule