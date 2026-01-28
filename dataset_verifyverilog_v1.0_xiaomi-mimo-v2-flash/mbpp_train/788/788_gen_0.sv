module CreateStringArray(
    input clk,
    input rst_n,
    input start,
    input [7:0] list_str_id_0,
    input [7:0] list_str_id_1,
    input [7:0] input_str_id,
    output reg [7:0] result_0,
    output reg [7:0] result_1,
    output reg [7:0] result_2,
    output reg [3:0] result_len,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_LIST = 3'd1;
    localparam [2:0] LOAD_INPUT = 3'd2;
    localparam [2:0] WAIT_CYCLE = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    
    reg [2:0] state, next_state;
    reg [3:0] cycle_count;
    localparam [3:0] CYCLE_DELAY = 4'd5;
    
    // Input latching registers
    reg [7:0] latched_list_0;
    reg [7:0] latched_list_1;
    reg [7:0] latched_input;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_len <= 4'd0;
            done <= 1'b0;
            cycle_count <= 4'd0;
            latched_list_0 <= 8'd0;
            latched_list_1 <= 8'd0;
            latched_input <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        latched_list_0 <= list_str_id_0;
                        latched_list_1 <= list_str_id_1;
                        latched_input <= input_str_id;
                    end
                end
                
                LOAD_LIST: begin
                    result_0 <= latched_list_0;
                    result_1 <= latched_list_1;
                    result_len <= 4'd2;  // After loading list
                end
                
                LOAD_INPUT: begin
                    result_2 <= latched_input;
                    result_len <= 4'd3;  // Total length: list(2) + input(1)
                end
                
                WAIT_CYCLE: begin
                    cycle_count <= cycle_count + 4'd1;
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    result_0 <= 8'd0;
                    result_1 <= 8'd0;
                    result_2 <= 8'd0;
                    result_len <= 4'd0;
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    latched_list_0 <= 8'd0;
                    latched_list_1 <= 8'd0;
                    latched_input <= 8'd0;
                end
            endcase
        end
    end
    
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = LOAD_LIST;
                else next_state = IDLE;
            end
            
            LOAD_LIST: next_state = LOAD_INPUT;
            
            LOAD_INPUT: next_state = WAIT_CYCLE;
            
            WAIT_CYCLE: begin
                if (cycle_count >= CYCLE_DELAY) next_state = FINISH;
                else next_state = WAIT_CYCLE;
            end
            
            FINISH: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end
endmodule