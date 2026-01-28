module CumulativeSumModule (
    input clk,
    input rst_n,
    input start,
    input [1:0] tuple_count,
    input [2:0] tuple_lengths [0:2],
    input [7:0] values [0:11],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] LOAD_TUPLE     = 3'd1;
    localparam [2:0] READ_LENGTH    = 3'd2;
    localparam [2:0] SUM_VALUES     = 3'd3;
    localparam [2:0] NEXT_TUPLE     = 3'd4;
    localparam [2:0] WRITE_RESULT   = 3'd5;
    
    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] accumulator;
    reg [1:0] tuple_idx;        // 0 to 2
    reg [2:0] elem_idx;         // 0 to 3
    reg [2:0] current_length;   // Length of current tuple
    reg [2:0] cycle_counter;    // Prevent infinite loops
    localparam [2:0] MAX_CYCLES = 3'd7; // Max cycles for 3 tuples * 4 elements
    
    // Combinational next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD_TUPLE;
                else
                    next_state = IDLE;
            end
            
            LOAD_TUPLE: begin
                next_state = READ_LENGTH;
            end
            
            READ_LENGTH: begin
                next_state = SUM_VALUES;
            end
            
            SUM_VALUES: begin
                if (elem_idx < current_length - 1) begin
                    next_state = SUM_VALUES; // Continue current tuple
                end else begin
                    if (tuple_idx < tuple_count - 1)
                        next_state = NEXT_TUPLE; // Next tuple
                    else
                        next_state = WRITE_RESULT; // All tuples done
                end
            end
            
            NEXT_TUPLE: begin
                next_state = LOAD_TUPLE;
            end
            
            WRITE_RESULT: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            accumulator <= 16'd0;
            tuple_idx <= 2'd0;
            elem_idx <= 3'd0;
            current_length <= 3'd0;
            cycle_counter <= 3'd0;
        end else begin
            state <= next_state;
            cycle_counter <= cycle_counter + 3'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    accumulator <= 16'd0;
                    tuple_idx <= 2'd0;
                    elem_idx <= 3'd0;
                    cycle_counter <= 3'd0;
                    // result retains previous value
                end
                
                LOAD_TUPLE: begin
                    // Initialize for new tuple
                    elem_idx <= 3'd0;
                end
                
                READ_LENGTH: begin
                    // Read length from array
                    current_length <= tuple_lengths[tuple_idx];
                end
                
                SUM_VALUES: begin
                    // Add current element value to accumulator
                    // Values array is flattened: tuple0: 0-3, tuple1: 4-7, tuple2: 8-11
                    // Calculate index: tuple_idx * 4 + elem_idx
                    accumulator <= accumulator + values[tuple_idx * 4 + elem_idx];
                    
                    // Increment element index
                    elem_idx <= elem_idx + 3'd1;
                end
                
                NEXT_TUPLE: begin
                    // Move to next tuple
                    tuple_idx <= tuple_idx + 2'd1;
                end
                
                WRITE_RESULT: begin
                    result <= accumulator;
                    done <= 1'b1;
                end
                
                default: begin
                    // Default assignments
                    state <= IDLE;
                    result <= 16'd0;
                    done <= 1'b0;
                end
            endcase
            
            // Safety: timeout protection
            if (cycle_counter >= MAX_CYCLES) begin
                state <= IDLE;
                result <= accumulator;
                done <= 1'b1;
            end
        end
    end
endmodule