module InsertElementBeforeEach (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] element,
    input wire [7:0] arr_in [0:7],
    input wire [3:0] len_in,
    output reg [7:0] result [0:15],
    output reg [3:0] len_out,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] LOAD     = 3'd1;
    localparam [2:0] INSERT   = 3'd2;
    localparam [2:0] COPY     = 3'd3;
    localparam [2:0] FINISH   = 3'd4;
    localparam [2:0] CLEANUP  = 3'd5;

    // State machine registers
    reg [2:0] state, next_state;
    reg [3:0] input_idx;   // Index for input array (0-7)
    reg [4:0] output_idx;  // Index for output array (0-15)
    reg [3:0] cycle_count; // Counter to prevent infinite loops
    localparam [3:0] MAX_CYCLES = 4'd15;

    // Reset and State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            len_out <= 4'd0;
            input_idx <= 4'd0;
            output_idx <= 5'd0;
            cycle_count <= 4'd0;
            // Clear result array
            result[0] <= 8'd0;
            result[1] <= 8'd0;
            result[2] <= 8'd0;
            result[3] <= 8'd0;
            result[4] <= 8'd0;
            result[5] <= 8'd0;
            result[6] <= 8'd0;
            result[7] <= 8'd0;
            result[8] <= 8'd0;
            result[9] <= 8'd0;
            result[10] <= 8'd0;
            result[11] <= 8'd0;
            result[12] <= 8'd0;
            result[13] <= 8'd0;
            result[14] <= 8'd0;
            result[15] <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    input_idx <= 4'd0;
                    output_idx <= 5'd0;
                    cycle_count <= 4'd0;
                end

                LOAD: begin
                    // Calculate output length
                    len_out <= len_in * 4'd2;
                    // Handle edge case: if len_in is 0, go to cleanup
                    if (len_in == 4'd0) begin
                        // Don't increment state yet, handled in next_state logic
                    end
                end

                INSERT: begin
                    result[output_idx] <= element;
                    output_idx <= output_idx + 5'd1;
                    cycle_count <= cycle_count + 4'd1;
                end

                COPY: begin
                    result[output_idx] <= arr_in[input_idx];
                    output_idx <= output_idx + 5'd1;
                    input_idx <= input_idx + 4'd1;
                    cycle_count <= cycle_count + 4'd1;
                end

                FINISH: begin
                    done <= 1'b1;
                end

                CLEANUP: begin
                    // Clear done and prepare for next operation
                    done <= 1'b0;
                    len_out <= 4'd0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end

            LOAD: begin
                if (len_in == 4'd0) begin
                    next_state = CLEANUP;
                end else begin
                    next_state = INSERT;
                end
            end

            INSERT: begin
                // Always transition to COPY after inserting
                next_state = COPY;
            end

            COPY: begin
                // Check if we are done with this element (should always be done)
                // Check if we processed all input elements
                if (input_idx >= len_in) begin
                    next_state = FINISH;
                end else begin
                    // Loop back to INSERT for the next element
                    next_state = INSERT;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            CLEANUP: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule