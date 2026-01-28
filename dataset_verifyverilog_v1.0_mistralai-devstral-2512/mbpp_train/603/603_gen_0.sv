module LudicSieve(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    output reg done,
    output reg result_valid,
    output reg [3:0] result_count,
    output reg [3:0] result_data_0,
    output reg [3:0] result_data_1,
    output reg [3:0] result_data_2,
    output reg [3:0] result_data_3,
    output reg [3:0] result_data_4,
    output reg [3:0] result_data_5,
    output reg [3:0] result_data_6,
    output reg [3:0] result_data_7,
    output reg [3:0] result_data_8,
    output reg [3:0] result_data_9
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] INIT    = 3'd1;
    localparam [2:0] SIEVE   = 3'd2;
    localparam [2:0] OUTPUT  = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [3:0] array [0:15];
    reg [3:0] step;
    reg [3:0] current_pos;
    reg [3:0] remove_pos;
    reg [3:0] valid_count;
    reg [3:0] output_index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Initialize array with 1-16
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_valid <= 1'b0;
            result_count <= 4'd0;
            result_data_0 <= 4'd0;
            result_data_1 <= 4'd0;
            result_data_2 <= 4'd0;
            result_data_3 <= 4'd0;
            result_data_4 <= 4'd0;
            result_data_5 <= 4'd0;
            result_data_6 <= 4'd0;
            result_data_7 <= 4'd0;
            result_data_8 <= 4'd0;
            result_data_9 <= 4'd0;
            cycle_count <= 8'd0;
            
            // Initialize array
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                array[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    // Initialize array with 1-16
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        array[i] <= i + 1;
                    end
                    valid_count <= 4'd16;
                    current_pos <= 4'd1;
                    next_state <= SIEVE;
                end

                SIEVE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Get step value from current position
                    step <= array[current_pos];
                    
                    // Remove every step-th element starting from current_pos
                    remove_pos <= current_pos + step;
                    
                    // Mark elements for removal
                    if (remove_pos < 16) begin
                        array[remove_pos] <= 4'd0;
                        valid_count <= valid_count - 4'd1;
                    end
                    
                    // Move to next position
                    current_pos <= current_pos + 4'd1;
                    
                    // Check if done with sieve
                    if (current_pos >= 15 || cycle_count >= MAX_CYCLES) begin
                        next_state <= OUTPUT;
                        output_index <= 4'd0;
                    end else begin
                        next_state <= SIEVE;
                    end
                end

                OUTPUT: begin
                    // Output valid elements to result_data ports
                    integer i;
                    reg [3:0] temp_count;
                    temp_count <= 4'd0;
                    
                    for (i = 0; i < 16; i = i + 1) begin
                        if (array[i] != 4'd0 && temp_count < 10) begin
                            case (temp_count)
                                4'd0: result_data_0 <= array[i];
                                4'd1: result_data_1 <= array[i];
                                4'd2: result_data_2 <= array[i];
                                4'd3: result_data_3 <= array[i];
                                4'd4: result_data_4 <= array[i];
                                4'd5: result_data_5 <= array[i];
                                4'd6: result_data_6 <= array[i];
                                4'd7: result_data_7 <= array[i];
                                4'd8: result_data_8 <= array[i];
                                4'd9: result_data_9 <= array[i];
                            endcase
                            temp_count <= temp_count + 4'd1;
                        end
                    end
                    
                    result_count <= temp_count;
                    result_valid <= 1'b1;
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

endmodule