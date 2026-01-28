module SlavkoGame(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire [3:0] len,
    output reg [63:0] result,
    output reg done,
    output reg win
);
    
    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] PROCESS   = 3'd2;
    localparam [2:0] COMPARE   = 3'd3;
    localparam [2:0] OUTPUT    = 3'd4;
    
    reg [2:0] state;
    reg [3:0] char_count;
    reg [3:0] turn_count;
    reg [3:0] array_index;
    reg [3:0] min_index;
    reg [7:0] min_char;
    reg [7:0] current_char;
    
    // Character buffer (16x8-bit)
    reg [7:0] char_buffer [0:15];
    
    // Words (8x8-bit each)
    reg [7:0] slavko_word [0:7];
    reg [7:0] mirko_word [0:7];
    reg [3:0] slavko_ptr;
    reg [3:0] mirko_ptr;
    
    // Remaining letters tracking
    reg [15:0] remaining_mask;
    
    // Cycle counter for safety
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_count <= 4'd0;
            turn_count <= 4'd0;
            array_index <= 4'd0;
            min_index <= 4'd0;
            min_char <= 8'd0;
            current_char <= 8'd0;
            slavko_ptr <= 4'd0;
            mirko_ptr <= 4'd0;
            remaining_mask <= 16'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            win <= 1'b0;
            result <= 64'd0;
            
            // Initialize buffers
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                char_buffer[i] <= 8'd0;
            end
            for (i = 0; i < 8; i = i + 1) begin
                slavko_word[i] <= 8'd0;
                mirko_word[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    win <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= LOAD;
                        char_count <= 4'd0;
                        remaining_mask <= 16'd0;
                    end
                end
                
                LOAD: begin
                    // Load N characters
                    if (char_count < len) begin
                        char_buffer[char_count] <= char_in;
                        remaining_mask[char_count] <= 1'b1;
                        char_count <= char_count + 4'd1;
                    end else begin
                        state <= PROCESS;
                        turn_count <= 4'd0;
                        array_index <= 4'd0;
                        min_index <= 4'd0;
                        min_char <= 8'd255;
                    end
                end
                
                PROCESS: begin
                    // Process turns (N/2 turns each)
                    if (turn_count < len[3:1]) begin  // len/2
                        // Mirko's turn (even turns: 0,2,4...)
                        if (turn_count[0] == 1'b0) begin
                            // Find rightmost remaining
                            integer i;
                            for (i = 15; i >= 0; i = i - 1) begin
                                if (remaining_mask[i]) begin
                                    mirko_word[mirko_ptr] <= char_buffer[i];
                                    remaining_mask[i] <= 1'b0;
                                    mirko_ptr <= mirko_ptr + 4'd1;
                                    break;
                                end
                            end
                            turn_count <= turn_count + 4'd1;
                        end
                        // Slavko's turn (odd turns: 1,3,5...)
                        else begin
                            // Find minimum remaining character
                            if (array_index == 4'd0) begin
                                min_char <= 8'd255;
                                min_index <= 4'd0;
                            end
                            
                            if (array_index < len) begin
                                if (remaining_mask[array_index]) begin
                                    current_char <= char_buffer[array_index];
                                    if (current_char < min_char) begin
                                        min_char <= current_char;
                                        min_index <= array_index;
                                    end
                                end
                                array_index <= array_index + 4'd1;
                            end else begin
                                // Store Slavko's choice
                                slavko_word[slavko_ptr] <= min_char;
                                remaining_mask[min_index] <= 1'b0;
                                slavko_ptr <= slavko_ptr + 4'd1;
                                turn_count <= turn_count + 4'd1;
                                array_index <= 4'd0;
                            end
                        end
                    end else begin
                        state <= COMPARE;
                    end
                end
                
                COMPARE: begin
                    // Compare words lexicographically
                    integer i;
                    win <= 1'b0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (slavko_word[i] < mirko_word[i]) begin
                            win <= 1'b1;
                            break;
                        end else if (slavko_word[i] > mirko_word[i]) begin
                            win <= 1'b0;
                            break;
                        end
                    end
                    state <= OUTPUT;
                end
                
                OUTPUT: begin
                    // Pack Slavko's word into result
                    result[7:0]   <= slavko_word[0];
                    result[15:8]  <= slavko_word[1];
                    result[23:16] <= slavko_word[2];
                    result[31:24] <= slavko_word[3];
                    result[39:32] <= slavko_word[4];
                    result[47:40] <= slavko_word[5];
                    result[55:48] <= slavko_word[6];
                    result[63:56] <= slavko_word[7];
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
            
            // Safety: cycle counter
            if (cycle_count < MAX_CYCLES) begin
                cycle_count <= cycle_count + 8'd1;
            end else begin
                state <= IDLE;
                done <= 1'b1;
            end
        end
    end
endmodule