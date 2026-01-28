module ShortestSubarrayModule(
    input clk,
    input rst_n,
    input start,
    input query_type,
    input [3:0] pos,
    input [3:0] new_val,
    input [7:0] current_val_in,
    output reg [3:0] result,
    output reg done,
    output reg [3:0] addr,
    output reg write_en,
    output reg [3:0] addr_wr,
    output reg [7:0] new_val_out
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] READ      = 3'd1;
    localparam [2:0] COMPUTE   = 3'd2;
    localparam [2:0] WRITE     = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // Array storage (16 elements, 4-bit each)
    reg [3:0] array [0:15];
    integer i;

    // Sliding window variables
    reg [3:0] left, right;
    reg [3:0] min_length;
    reg [3:0] distinct_count;
    reg [3:0] count [0:7]; // count[0] for 1, count[1] for 2, ..., count[7] for 8
    reg [3:0] current_val;
    reg [3:0] temp_pos;

    // Clamp new_val to 1-8
    always @(*) begin
        if (new_val < 4'd1) begin
            new_val_out = 4'd1;
        end else if (new_val > 4'd8) begin
            new_val_out = 4'd8;
        end else begin
            new_val_out = new_val;
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            write_en <= 1'b0;
            addr <= 4'd0;
            addr_wr <= 4'd0;
            
            // Initialize array
            for (i = 0; i < 16; i = i + 1) begin
                array[i] <= 4'd0;
            end
            
            // Initialize sliding window variables
            left <= 4'd0;
            right <= 4'd0;
            min_length <= 4'd16;
            distinct_count <= 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                count[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    if (query_type == 1'b0) begin
                        next_state = WRITE;
                    end else begin
                        next_state = READ;
                    end
                end
            end
            
            READ: begin
                if (addr == 4'd15) begin
                    next_state = COMPUTE;
                end
            end
            
            COMPUTE: begin
                if (cycle_count >= MAX_CYCLES || (distinct_count == 4'd8 && min_length != 4'd16)) begin
                    next_state = DONE_STATE;
                end
            end
            
            WRITE: begin
                next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Cycle counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: cycle_count <= 8'd0;
                READ: cycle_count <= cycle_count + 8'd1;
                COMPUTE: cycle_count <= cycle_count + 8'd1;
                WRITE: cycle_count <= cycle_count + 8'd1;
                DONE_STATE: cycle_count <= 8'd0;
                default: cycle_count <= 8'd0;
            endcase
        end
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            result <= 4'd0;
            write_en <= 1'b0;
            addr <= 4'd0;
            addr_wr <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    write_en <= 1'b0;
                end
                
                READ: begin
                    done <= 1'b0;
                    write_en <= 1'b0;
                    addr <= addr + 4'd1;
                    if (current_val_in != 8'd0) begin
                        array[addr] <= current_val_in[3:0];
                    end
                end
                
                COMPUTE: begin
                    done <= 1'b0;
                    write_en <= 1'b0;
                    
                    // Sliding window algorithm
                    if (right < 4'd16) begin
                        current_val = array[right];
                        
                        // Update count for current_val
                        if (current_val >= 4'd1 && current_val <= 4'd8) begin
                            if (count[current_val - 4'd1] == 4'd0) begin
                                distinct_count = distinct_count + 4'd1;
                            end
                            count[current_val - 4'd1] = count[current_val - 4'd1] + 4'd1;
                        end
                        
                        // Try to move left pointer
                        while (left <= right && (array[left] < 4'd1 || array[left] > 4'd8 || count[array[left] - 4'd1] > 4'd1)) begin
                            if (array[left] >= 4'd1 && array[left] <= 4'd8) begin
                                count[array[left] - 4'd1] = count[array[left] - 4'd1] - 4'd1;
                            end
                            left = left + 4'd1;
                        end
                        
                        // Update min_length if all distinct values found
                        if (distinct_count == 4'd8) begin
                            if ((right - left + 4'd1) < min_length) begin
                                min_length = right - left + 4'd1;
                            end
                        end
                        
                        right = right + 4'd1;
                    end
                    
                    // Check if done
                    if (right == 4'd16 || cycle_count >= MAX_CYCLES) begin
                        if (distinct_count == 4'd8) begin
                            result = min_length;
                        end else begin
                            result = 4'd15; // -1
                        end
                    end
                end
                
                WRITE: begin
                    done <= 1'b0;
                    write_en <= 1'b1;
                    addr_wr <= pos - 4'd1;
                    array[addr_wr] <= new_val_out[3:0];
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    write_en <= 1'b0;
                    
                    // Reset sliding window variables
                    left <= 4'd0;
                    right <= 4'd0;
                    min_length <= 4'd16;
                    distinct_count <= 4'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        count[i] <= 4'd0;
                    end
                end
                
                default: begin
                    done <= 1'b0;
                    write_en <= 1'b0;
                end
            endcase
        end
    end

endmodule