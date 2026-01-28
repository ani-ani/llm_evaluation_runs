module is_bored(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [5:0] char_index,
    input valid,
    output reg [3:0] result,
    output reg done,
    output reg [5:0] read_index
);

    // State declarations
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] WAIT_READ    = 3'd1;
    localparam [2:0] PROCESS_CHAR = 3'd2;
    localparam [2:0] DONE         = 3'd3;
    
    // Internal registers
    reg [2:0] state, next_state;
    reg [5:0] char_idx;
    reg [3:0] count;
    reg sentence_start;
    reg [6:0] cycle_count; // Maximum 70 cycles
    
    // ASCII constants
    localparam [7:0] CHAR_I      = 8'h49;
    localparam [7:0] CHAR_PERIOD = 8'h2E;
    localparam [7:0] CHAR_QMARK  = 8'h3F;
    localparam [7:0] CHAR_EXCLAM = 8'h21;
    localparam [7:0] CHAR_NULL   = 8'h00;
    localparam [5:0] MAX_INDEX   = 6'd63;
    localparam [6:0] MAX_CYCLES  = 7'd70;
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = WAIT_READ;
                else
                    next_state = IDLE;
            end
            
            WAIT_READ: begin
                if (valid && (char_index == char_idx))
                    next_state = PROCESS_CHAR;
                else
                    next_state = WAIT_READ;
            end
            
            PROCESS_CHAR: begin
                if (char_in == CHAR_NULL || char_idx >= MAX_INDEX || cycle_count >= MAX_CYCLES)
                    next_state = DONE;
                else
                    next_state = WAIT_READ;
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            read_index <= 6'd0;
            char_idx <= 6'd0;
            count <= 4'd0;
            sentence_start <= 1'b1; // First character is sentence start
            cycle_count <= 7'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        read_index <= 6'd0;
                        char_idx <= 6'd0;
                        count <= 4'd0;
                        sentence_start <= 1'b1;
                        cycle_count <= 7'd0;
                    end
                end
                
                WAIT_READ: begin
                    // Keep requesting current index
                    read_index <= char_idx;
                    cycle_count <= cycle_count + 7'd1;
                end
                
                PROCESS_CHAR: begin
                    // Process current character
                    if (char_in == CHAR_I && sentence_start) begin
                        count <= count + 4'd1;
                    end
                    
                    // Update sentence_start for next character
                    if (char_in == CHAR_PERIOD || char_in == CHAR_QMARK || char_in == CHAR_EXCLAM) begin
                        sentence_start <= 1'b1;
                    end else begin
                        sentence_start <= 1'b0;
                    end
                    
                    // Move to next character
                    char_idx <= char_idx + 6'd1;
                end
                
                DONE: begin
                    result <= count;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 4'd0;
                    done <= 1'b0;
                    read_index <= 6'd0;
                    char_idx <= 6'd0;
                    count <= 4'd0;
                    sentence_start <= 1'b1;
                    cycle_count <= 7'd0;
                end
            endcase
        end
    end

endmodule