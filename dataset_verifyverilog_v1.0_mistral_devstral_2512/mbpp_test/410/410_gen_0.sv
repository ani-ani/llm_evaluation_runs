module min_integer_finder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [0:7] valid,
    input wire [0:7] type_code,
    input wire [7:0] value [0:7],
    input wire [2:0] num_elements,
    output reg [7:0] min_value,
    output reg done,
    output reg error
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] SCAN    = 3'd1;
    localparam [2:0] UPDATE  = 3'd2;
    localparam [2:0] DONE    = 3'd3;
    
    reg [2:0] state, next_state;
    reg [2:0] index;
    reg [7:0] current_min;
    reg found_integer;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            index <= 3'd0;
            current_min <= 8'd0;
            found_integer <= 1'b0;
            min_value <= 8'd0;
            done <= 1'b0;
            error <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= SCAN;
                        index <= 3'd0;
                        found_integer <= 1'b0;
                        current_min <= 8'd255; // Initialize to max value
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                SCAN: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (index < num_elements && cycle_count < MAX_CYCLES) begin
                        if (valid[index] && !type_code[index]) begin
                            next_state <= UPDATE;
                        end else begin
                            index <= index + 3'd1;
                            next_state <= SCAN;
                        end
                    end else begin
                        if (found_integer) begin
                            next_state <= DONE;
                        end else begin
                            next_state <= IDLE;
                            error <= 1'b1;
                        end
                    end
                end
                
                UPDATE: begin
                    if (!found_integer) begin
                        found_integer <= 1'b1;
                        current_min <= value[index];
                    end else if (value[index] < current_min) begin
                        current_min <= value[index];
                    end
                    index <= index + 3'd1;
                    next_state <= SCAN;
                end
                
                DONE: begin
                    min_value <= current_min;
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
endmodule