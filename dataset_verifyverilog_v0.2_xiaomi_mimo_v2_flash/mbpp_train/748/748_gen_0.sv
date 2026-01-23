module capital_words_spaces (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [3:0] char_index,
    input input_valid,
    output reg [7:0] char_out,
    output reg [3:0] out_index,
    output reg output_valid,
    output reg done
);

    // Parameters
    parameter MAX_LEN = 16;
    parameter SPACE = 8'h20;
    
    // State encoding
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam PROCESS = 3'b010;
    localparam INSERT_SPACE = 3'b011;
    localparam DONE = 3'b100;

    // Registers for state machine
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Buffer for input characters (16x8 bits)
    reg [7:0] char_buffer [0:15];
    
    // Control registers
    reg [3:0] load_index;   // Index for loading characters
    reg [3:0] proc_index;   // Index for processing characters
    reg [3:0] out_idx_reg;  // Output index counter
    
    // Previous character tracking
    reg prev_char_upper;    // Flag: 1 if previous char was uppercase
    reg first_char;         // Flag: indicates first character processing
    reg space_pending;      // Flag: space needs to be output before current char
    
    // Detect uppercase letter (A-Z)
    wire is_uppercase;
    assign is_uppercase = (char_in >= 8'h41) && (char_in <= 8'h5A);
    
    // Previous char uppercase check (for stored buffer)
    wire prev_is_uppercase;
    assign prev_is_uppercase = (char_buffer[proc_index - 1] >= 8'h41) && (char_buffer[proc_index - 1] <= 8'h5A);
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
                else
                    next_state = IDLE;
            end
            
            LOAD: begin
                // Check if all 16 characters loaded or start signal released
                if (load_index >= MAX_LEN[3:0])
                    next_state = PROCESS;
                else
                    next_state = LOAD;
            end
            
            PROCESS: begin
                if (proc_index >= MAX_LEN[3:0]) begin
                    // Check if we need to output a final pending space
                    if (space_pending)
                        next_state = INSERT_SPACE;
                    else
                        next_state = DONE;
                end else begin
                    // Determine if space insertion is needed
                    if (!first_char) begin
                        // Check current character type
                        wire curr_is_upper;
                        assign curr_is_upper = (char_buffer[proc_index] >= 8'h41) && (char_buffer[proc_index] <= 8'h5A);
                        wire prev_is_upper;
                        assign prev_is_upper = (char_buffer[proc_index - 1] >= 8'h41) && (char_buffer[proc_index - 1] <= 8'h5A);
                        
                        if (curr_is_upper && !prev_is_upper) begin
                            next_state = INSERT_SPACE;
                        end else begin
                            next_state = PROCESS;
                        end
                    end else begin
                        next_state = PROCESS;
                    end
                end
            end
            
            INSERT_SPACE: begin
                // After inserting space, return to PROCESS to output the character
                next_state = PROCESS;
            end
            
            DONE: begin
                if (!start)
                    next_state = IDLE;
                else
                    next_state = DONE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // State register and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            load_index <= 4'd0;
            proc_index <= 4'd0;
            out_idx_reg <= 4'd0;
            prev_char_upper <= 1'b0;
            first_char <= 1'b0;
            space_pending <= 1'b0;
            char_out <= 8'h00;
            out_index <= 4'd0;
            output_valid <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            // Default outputs
            output_valid <= 1'b0;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    load_index <= 4'd0;
                    proc_index <= 4'd0;
                    out_idx_reg <= 4'd0;
                    first_char <= 1'b1;
                    space_pending <= 1'b0;
                end
                
                LOAD: begin
                    if (input_valid && char_index < MAX_LEN[3:0]) begin
                        char_buffer[char_index] <= char_in;
                        // Track max loaded index
                        if (char_index >= load_index)
                            load_index <= char_index + 1;
                    end
                end
                
                PROCESS: begin
                    // Output the character at current position
                    if (proc_index < MAX_LEN[3:0]) begin
                        char_out <= char_buffer[proc_index];
                        out_index <= out_idx_reg;
                        output_valid <= 1'b1;
                        
                        // Update tracking
                        if (first_char) begin
                            first_char <= 1'b0;
                            prev_char_upper <= (char_buffer[proc_index] >= 8'h41) && (char_buffer[proc_index] <= 8'h5A);
                        end else begin
                            // Check if space insertion is needed for NEXT character
                            wire curr_is_upper;
                            assign curr_is_upper = (char_buffer[proc_index] >= 8'h41) && (char_buffer[proc_index] <= 8'h5A);
                            wire prev_is_upper;
                            assign prev_is_upper = (char_buffer[proc_index - 1] >= 8'h41) && (char_buffer[proc_index - 1] <= 8'h5A);
                            
                            // Prepare space_pending for next iteration
                            if (curr_is_upper && !prev_is_upper) begin
                                space_pending <= 1'b1;
                            end else begin
                                space_pending <= 1'b0;
                            end
                            
                            prev_char_upper <= curr_is_upper;
                        end
                        
                        proc_index <= proc_index + 1;
                        out_idx_reg <= out_idx_reg + 1;
                    end
                end
                
                INSERT_SPACE: begin
                    char_out <= SPACE;
                    out_index <= out_idx_reg;
                    output_valid <= 1'b1;
                    out_idx_reg <= out_idx_reg + 1;
                    space_pending <= 1'b0;
                end
                
                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule

module capital_words_spaces_v2 (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [3:0] char_index,
    input input_valid,
    output reg [7:0] char_out,
    output reg [3:0] out_index,
    output reg output_valid,
    output reg done
);

    parameter MAX_LEN = 16;
    parameter SPACE = 8'h20;
    
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam PROCESS = 3'b010;
    localparam INSERT_SPACE = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] char_buffer [0:15];
    reg [3:0] load_cnt;
    reg [3:0] read_ptr;
    reg [3:0] write_ptr;
    
    // Flags
    reg space_needed; // Indicates we need to output a space before the next char
    reg prev_upper;   // Type of last char outputted
    reg started;      // Processing started

    // Helper to check uppercase of buffer data
    wire buf_is_upper;
    assign buf_is_upper = (char_buffer[read_ptr] >= 8'h41) && (char_buffer[read_ptr] <= 8'h5A);

    // State Transition Logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? LOAD : IDLE;
            
            LOAD: begin
                if (load_cnt >= MAX_LEN[3:0] && !start)
                    next_state = PROCESS;
                else
                    next_state = LOAD;
            end
            
            PROCESS: begin
                if (read_ptr >= MAX_LEN[3:0]) begin
                    next_state = DONE;
                end else if (space_needed) begin
                    next_state = INSERT_SPACE;
                end else begin
                    next_state = PROCESS;
                end
            end
            
            INSERT_SPACE: begin
                next_state = PROCESS;
            end
            
            DONE: next_state = start ? IDLE : DONE;
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_out <= 8'h00;
            out_index <= 4'd0;
            output_valid <= 1'b0;
            done <= 1'b0;
            load_cnt <= 4'd0;
            read_ptr <= 4'd0;
            write_ptr <= 4'd0;
            space_needed <= 1'b0;
            prev_upper <= 1'b0;
            started <= 1'b0;
        end else begin
            state <= next_state;
            output_valid <= 1'b0;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    load_cnt <= 4'd0;
                    read_ptr <= 4'd0;
                    write_ptr <= 4'd0;
                    space_needed <= 1'b0;
                    prev_upper <= 1'b0;
                    started <= 1'b0;
                end
                
                LOAD: begin
                    if (input_valid && char_index < MAX_LEN) begin
                        char_buffer[char_index] <= char_in;
                        if (char_index >= load_cnt)
                            load_cnt <= char_index + 1;
                    end
                end
                
                PROCESS: begin
                    if (read_ptr < MAX_LEN) begin
                        if (!space_needed) begin
                            // Output current character
                            char_out <= char_buffer[read_ptr];
                            out_index <= write_ptr;
                            output_valid <= 1'b1;
                            write_ptr <= write_ptr + 1;
                            
                            // Determine if space is needed for the NEXT character
                            if (started) begin
                                // Check transition: Current is Upper AND Previous was Lower
                                // We need to check the CURRENT char (just outputted) against the PREVIOUS outputted
                                if (buf_is_upper && !prev_upper) begin
                                    space_needed <= 1'b1;
                                end else begin
                                    space_needed <= 1'b0;
                                end
                                prev_upper <= buf_is_upper;
                            end else begin
                                // First character
                                prev_upper <= buf_is_upper;
                                started <= 1'b1;
                                space_needed <= 1'b0;
                            end
                            
                            read_ptr <= read_ptr + 1;
                        end else begin
                            // space_needed was high, but we are in PROCESS state due to state transition logic
                            // This branch shouldn't be reached if transition logic is correct, 
                            // but if it falls through here, we handle the char without space.
                            // However, we handle space in INSERT_SPACE state below.
                        end
                    end
                end
                
                INSERT_SPACE: begin
                    char_out <= SPACE;
                    out_index <= write_ptr;
                    output_valid <= 1'b1;
                    write_ptr <= write_ptr + 1;
                    space_needed <= 1'b0;
                end
                
                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule

module capital_words_spaces (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [3:0] char_index,
    input input_valid,
    output reg [7:0] char_out,
    output reg [3:0] out_index,
    output reg output_valid,
    output reg done
);

    // Parameters
    parameter MAX_LEN = 16;
    localparam SPACE = 8'h20;
    
    // State Definitions
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam PROCESS_CHECK = 3'b010;
    localparam OUTPUT_CHAR = 3'b011;
    localparam OUTPUT_SPACE = 3'b100;
    localparam DONE = 3'b101;

    // Registers
    reg [2:0] state, next_state;
    reg [7:0] char_buffer [0:15];
    reg [3:0] load_cnt;
    reg [3:0] read_idx;
    reg [3:0] write_idx;
    
    // Internal Flags
    reg last_char_upper; // Was the previous output character uppercase?
    reg is_first_char;   // Are we processing the first character of the string?
    
    // Combinational Helper: Check if loaded character is uppercase
    wire current_is_upper;
    assign current_is_upper = (char_buffer[read_idx] >= 8'h41) && (char_buffer[read_idx] <= 8'h5A);

    // State Transition Logic
    always @(*) begin
        case (state)
            IDLE:           next_state = start ? LOAD : IDLE;
            
            LOAD:           next_state = (load_cnt >= MAX_LEN && !start) ? PROCESS_CHECK : LOAD;
            
            PROCESS_CHECK:  begin
                                if (read_idx >= MAX_LEN) begin
                                    next_state = DONE;
                                end else begin
                                    // Determine logic:
                                    // 1. First char: Output Char (no space)
                                    // 2. Current Upper & Last NOT Upper: Output Space then Char
                                    // 3. Else: Output Char
                                    
                                    if (is_first_char) begin
                                        next_state = OUTPUT_CHAR;
                                    end else if (current_is_upper && !last_char_upper) begin
                                        next_state = OUTPUT_SPACE;
                                    end else begin
                                        next_state = OUTPUT_CHAR;
                                    end
                                end
                            end
            
            OUTPUT_SPACE:   next_state = OUTPUT_CHAR;
            
            OUTPUT_CHAR:    next_state = PROCESS_CHECK;
            
            DONE:           next_state = start ? IDLE : DONE;
            
            default:        next_state = IDLE;
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            load_cnt <= 4'd0;
            read_idx <= 4'd0;
            write_idx <= 4'd0;
            last_char_upper <= 1'b0;
            is_first_char <= 1'b1;
            char_out <= 8'h00;
            out_index <= 4'd0;
            output_valid <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            output_valid <= 1'b0;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    load_cnt <= 4'd0;
                    read_idx <= 4'd0;
                    write_idx <= 4'd0;
                    is_first_char <= 1'b1;
                    last_char_upper <= 1'b0;
                end
                
                LOAD: begin
                    if (input_valid && char_index < MAX_LEN) begin
                        char_buffer[char_index] <= char_in;
                        // Keep track of how many chars loaded (max index + 1)
                        if (char_index >= load_cnt)
                            load_cnt <= char_index + 1;
                    end
                end
                
                // PROCESS_CHECK is purely combinational logic transition
                // No action needed here in sequential block
                
                OUTPUT_SPACE: begin
                    char_out <= SPACE;
                    out_index <= write_idx;
                    output_valid <= 1'b1;
                    write_idx <= write_idx + 1;
                end
                
                OUTPUT_CHAR: begin
                    char_out <= char_buffer[read_idx];
                    out_index <= write_idx;
                    output_valid <= 1'b1;
                    
                    // Update flags for next iteration
                    read_idx <= read_idx + 1;
                    write_idx <= write_idx + 1;
                    
                    if (is_first_char) begin
                        is_first_char <= 1'b0;
                        last_char_upper <= current_is_upper;
                    end else begin
                        // If we just output a space (state was OUTPUT_SPACE -> OUTPUT_CHAR), 
                        // or just output char, update last_char_upper
                        last_char_upper <= current_is_upper;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule