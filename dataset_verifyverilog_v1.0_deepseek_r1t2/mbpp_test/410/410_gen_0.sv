module min_finder(
    input clk,
    input rst_n,
    input start,
    input [7:0] valid,
    input [7:0] type_code,
    input [63:0] value,
    input [2:0] num_elements,
    output reg [7:0] min_value,
    output reg done,
    output reg error
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SCAN = 2'd1;
    localparam [1:0] UPDATE = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state;
    reg [2:0] current_index;
    reg [7:0] min_reg;
    reg found_flag;
    reg [7:0] cycle_count;
    
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Current value extraction
    reg [7:0] current_value;
    always @(*) begin
        case (current_index)
            3'd0: current_value = value[7:0];
            3'd1: current_value = value[15:8];
            3'd2: current_value = value[23:16];
            3'd3: current_value = value[31:24];
            3'd4: current_value = value[39:32];
            3'd5: current_value = value[47:40];
            3'd6: current_value = value[55:48];
            3'd7: current_value = value[63:56];
            default: current_value = 8'd0;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_index <= 3'd0;
            min_reg <= 8'd255;
            found_flag <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            min_value <= 8'd0;
            cycle_count <= 8'd0;
        end else begin
            // Cycle count logic
            cycle_count <= (state == IDLE && start) ? 8'd1 : (state != IDLE) ? cycle_count + 8'd1 : 8'd0;
            
            // Default output assignments
            done <= 1'b0;
            error <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        current_index <= 3'd0;
                        min_reg <= 8'd255;
                        found_flag <= 1'b0;
                        state <= SCAN;
                    end
                end
                
                SCAN: begin
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end else if (current_index < num_elements) begin
                        if (valid[current_index] && (type_code[current_index] == 1'b0)) begin
                            state <= UPDATE;
                        end else begin
                            current_index <= current_index + 3'd1;
                        end
                    end else begin
                        state <= DONE_STATE;
                    end
                end
                
                UPDATE: begin
                    if (current_value < min_reg) begin
                        min_reg <= current_value;
                    end
                    found_flag <= 1'b1;
                    current_index <= current_index + 3'd1;
                    state <= SCAN;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    error <= !found_flag || (cycle_count >= MAX_CYCLES);
                    min_value <= min_reg;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule