module SlimeMergingGame(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [16:0] n_in,
    output reg [4:0] result_v [0:16],
    output reg [4:0] result_len,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOAD       = 3'd1;
    localparam [2:0] PROCESSING = 3'd2;
    localparam [2:0] OUTPUT     = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [16:0] counter;          // Counter for n_in
    reg [16:0] temp_counter;     // Working copy for processing
    reg [4:0] bit_position;      // Current bit position (0-16)
    reg [4:0] result_count;      // Number of slimes found
    reg [4:0] output_idx;        // Index for output ordering
    reg [4:0] result_store [0:16]; // Store slimes in discovery order
    reg processing_done;          // Flag when processing complete
    reg [7:0] cycle_count;       // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd200;

    integer i;

    // State register and next state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_len <= 5'd0;
            done <= 1'b0;
            counter <= 17'd0;
            temp_counter <= 17'd0;
            bit_position <= 5'd0;
            result_count <= 5'd0;
            output_idx <= 5'd0;
            processing_done <= 1'b0;
            cycle_count <= 8'd0;
            for (i = 0; i < 17; i = i + 1) begin
                result_v[i] <= 5'd0;
                result_store[i] <= 5'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_len <= 5'd0;
                    cycle_count <= 8'd0;
                    counter <= 17'd0;
                    temp_counter <= 17'd0;
                    bit_position <= 5'd0;
                    result_count <= 5'd0;
                    output_idx <= 5'd0;
                    processing_done <= 1'b0;
                    for (i = 0; i < 17; i = i + 1) begin
                        result_v[i] <= 5'd0;
                        result_store[i] <= 5'd0;
                    end
                    if (start) begin
                        counter <= n_in;
                    end
                end
                
                LOAD: begin
                    temp_counter <= counter;
                    bit_position <= 5'd0;
                    result_count <= 5'd0;
                    output_idx <= 5'd0;
                    processing_done <= 1'b0;
                    cycle_count <= 8'd0;
                    for (i = 0; i < 17; i = i + 1) begin
                        result_store[i] <= 5'd0;
                    end
                end
                
                PROCESSING: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (temp_counter[0] == 1'b1) begin
                        // Store slime value (bit_position + 1)
                        result_store[result_count] <= bit_position + 5'd1;
                        result_count <= result_count + 5'd1;
                    end
                    
                    temp_counter <= temp_counter >> 1;
                    bit_position <= bit_position + 5'd1;
                    
                    // Exit condition: counter becomes 0 or max cycles reached
                    if (temp_counter == 17'd0 || cycle_count >= MAX_CYCLES) begin
                        processing_done <= 1'b1;
                    end
                end
                
                OUTPUT: begin
                    // Store results in reverse order (MSB to LSB)
                    // output_idx goes from 0 to result_count-1
                    // result_store[0] = lowest bit, result_store[result_count-1] = highest bit
                    // We need to reverse: result_v[0] = highest
                    if (output_idx < result_count) begin
                        result_v[output_idx] <= result_store[result_count - 1 - output_idx];
                        output_idx <= output_idx + 5'd1;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    result_len <= result_count;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end else begin
                    next_state = IDLE;
                end
            end
            
            LOAD: begin
                // Start processing
                next_state = PROCESSING;
            end
            
            PROCESSING: begin
                // Check if processing is done
                if (processing_done) begin
                    next_state = OUTPUT;
                end else begin
                    next_state = PROCESSING;
                end
            end
            
            OUTPUT: begin
                // Check if all outputs are stored
                if (output_idx >= result_count) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = OUTPUT;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule