module dictionary_filter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] threshold,
    input wire [63:0] key_in [0:7],
    input wire [7:0] value_in [0:7],
    input wire valid_in [0:7],
    output reg [63:0] key_out [0:7],
    output reg [7:0] value_out [0:7],
    output reg valid_out [0:7],
    output reg [3:0] count,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] READ     = 3'd1;
    localparam [2:0] FILTER   = 3'd2;
    localparam [2:0] OUTPUT   = 3'd3;
    localparam [2:0] COMPLETE = 3'd4;
    
    reg [2:0] state, next_state;
    reg [2:0] index;
    reg [2:0] write_index;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd20;
    
    // Temporary storage for filtered entries (using packed format)
    reg [63:0] temp_key_buffer [0:7];
    reg [7:0] temp_value_buffer [0:7];
    reg temp_valid_buffer [0:7];
    
    integer i;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            count <= 4'd0;
            index <= 3'd0;
            write_index <= 3'd0;
            cycle_count <= 4'd0;
            
            // Reset all arrays
            for (i = 0; i < 8; i = i + 1) begin
                key_out[i] <= 64'd0;
                value_out[i] <= 8'd0;
                valid_out[i] <= 1'b0;
                temp_key_buffer[i] <= 64'd0;
                temp_value_buffer[i] <= 8'd0;
                temp_valid_buffer[i] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    write_index <= 3'd0;
                    count <= 4'd0;
                    
                    // Clear output buffer
                    for (i = 0; i < 8; i = i + 1) begin
                        key_out[i] <= 64'd0;
                        value_out[i] <= 8'd0;
                        valid_out[i] <= 1'b0;
                        temp_key_buffer[i] <= 64'd0;
                        temp_value_buffer[i] <= 8'd0;
                        temp_valid_buffer[i] <= 1'b0;
                    end
                    
                    if (start) begin
                        state <= READ;
                        index <= 3'd0;
                    end
                end
                
                READ: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Check if entry is valid and meets threshold
                    if (valid_in[index] && (value_in[index] >= threshold)) begin
                        temp_key_buffer[write_index] <= key_in[index];
                        temp_value_buffer[write_index] <= value_in[index];
                        temp_valid_buffer[write_index] <= 1'b1;
                        write_index <= write_index + 3'd1;
                        count <= count + 4'd1;
                    end
                    
                    if (index < 3'd7) begin
                        index <= index + 3'd1;
                    end else begin
                        state <= FILTER;
                        index <= 3'd0;
                    end
                end
                
                FILTER: begin
                    // This state processes filtered entries for output
                    // Since we already filtered in READ, we just transition
                    cycle_count <= cycle_count + 4'd1;
                    state <= OUTPUT;
                    index <= 3'd0;
                end
                
                OUTPUT: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Output filtered entries in order
                    if (index < count) begin
                        key_out[index] <= temp_key_buffer[index];
                        value_out[index] <= temp_value_buffer[index];
                        valid_out[index] <= temp_valid_buffer[index];
                        index <= index + 3'd1;
                    end else begin
                        state <= COMPLETE;
                    end
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Safety timeout - return to IDLE if stuck
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != COMPLETE) begin
                state <= IDLE;
            end
        end
    end

endmodule