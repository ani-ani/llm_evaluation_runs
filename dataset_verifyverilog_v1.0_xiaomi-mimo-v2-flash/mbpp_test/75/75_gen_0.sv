module tuple_filter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] tuple_data,
    input wire [2:0] element_index,
    input wire [1:0] tuple_index,
    input wire [7:0] K,
    output reg [7:0] filtered_tuple,
    output reg filtered_valid,
    output reg done
);

    // Parameters
    localparam [1:0] TUPLE_COUNT = 2'd4;
    localparam [2:0] TUPLE_WIDTH = 3'd3;
    localparam [7:0] DATA_WIDTH = 8'd8;

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] READ_TUPLE = 2'd1;
    localparam [1:0] CHECK_DIVISIBILITY = 2'd2;
    localparam [1:0] OUTPUT_TUPLE = 2'd3;

    // Registers
    reg [1:0] state, next_state;
    reg [7:0] element_buffer [0:2]; // Store tuple elements
    reg [2:0] elem_cnt; // Element counter within tuple
    reg [1:0] tuple_cnt; // Tuple counter
    reg all_divisible; // Flag for tuple validity
    reg [2:0] output_index; // Index for outputting elements
    reg [7:0] cycle_count; // Safety counter
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = READ_TUPLE;
                else
                    next_state = IDLE;
            end
            READ_TUPLE: begin
                // Wait for element_index to increment (simulating stream)
                // We assume external logic increments element_index
                // Transition to CHECK when element is received
                next_state = CHECK_DIVISIBILITY;
            end
            CHECK_DIVISIBILITY: begin
                // Check if we've processed all 3 elements of the tuple
                if (elem_cnt == (TUPLE_WIDTH - 1))
                    next_state = OUTPUT_TUPLE;
                else
                    next_state = READ_TUPLE;
            end
            OUTPUT_TUPLE: begin
                // Done outputting all elements
                if (output_index == (TUPLE_WIDTH - 1)) begin
                    if (tuple_cnt == (TUPLE_COUNT - 1))
                        next_state = IDLE;
                    else
                        next_state = READ_TUPLE;
                end else begin
                    next_state = OUTPUT_TUPLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            filtered_tuple <= 8'd0;
            filtered_valid <= 1'b0;
            done <= 1'b0;
            elem_cnt <= 3'd0;
            tuple_cnt <= 2'd0;
            all_divisible <= 1'b1;
            output_index <= 3'd0;
            cycle_count <= 8'd0;
            // Initialize buffer
            element_buffer[0] <= 8'd0;
            element_buffer[1] <= 8'd0;
            element_buffer[2] <= 8'd0;
        end else begin
            // Default outputs
            filtered_valid <= 1'b0;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    elem_cnt <= 3'd0;
                    tuple_cnt <= 2'd0;
                    all_divisible <= 1'b1;
                    output_index <= 3'd0;
                    cycle_count <= 8'd0;
                end

                READ_TUPLE: begin
                    // Store the incoming element
                    if (elem_cnt < TUPLE_WIDTH) begin
                        element_buffer[elem_cnt] <= tuple_data;
                    end
                    // Transition will happen on next clock from CHECK state
                end

                CHECK_DIVISIBILITY: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check divisibility of current element
                    if (elem_cnt < TUPLE_WIDTH) begin
                        if (element_buffer[elem_cnt] % K != 8'd0) begin
                            all_divisible <= 1'b0;
                        end
                    end
                    
                    // Increment element counter
                    if (elem_cnt < TUPLE_WIDTH - 1) begin
                        elem_cnt <= elem_cnt + 3'd1;
                    end else begin
                        elem_cnt <= 3'd0; // Reset for next tuple
                    end
                end

                OUTPUT_TUPLE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Output filtered tuple if valid
                    if (all_divisible) begin
                        filtered_valid <= 1'b1;
                        filtered_tuple <= element_buffer[output_index];
                    end
                    
                    // Increment output index
                    if (output_index < TUPLE_WIDTH - 1) begin
                        output_index <= output_index + 3'd1;
                    end else begin
                        output_index <= 3'd0;
                        
                        // Move to next tuple
                        if (tuple_cnt < TUPLE_COUNT - 1) begin
                            tuple_cnt <= tuple_cnt + 2'd1;
                            all_divisible <= 1'b1; // Reset for next tuple
                        end else begin
                            // All tuples processed
                            done <= 1'b1;
                        end
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
            
            // State transition
            state <= next_state;
            
            // Safety timeout
            if (cycle_count >= MAX_CYCLES) begin
                done <= 1'b1;
                state <= IDLE;
            end
        end
    end

endmodule