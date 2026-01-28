module SortDeduplicate(
    input clk,
    input rst_n,
    input start,
    input [3:0] len,
    input [7:0] arr [0:7],
    output reg [7:0] result [0:7],
    output reg [3:0] out_len,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] READ      = 3'd1;
    localparam [2:0] SORT      = 3'd2;
    localparam [2:0] DEDUP     = 3'd3;
    localparam [2:0] COMPLETE  = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] buffer [0:7];
    reg [7:0] sorted [0:7];
    reg [3:0] sort_pass;
    reg [3:0] sort_index;
    reg [3:0] dedup_index;
    reg [3:0] unique_count;
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            out_len <= 4'd0;
            
            // Initialize all result registers
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                result[i] <= 8'd0;
                buffer[i] <= 8'd0;
                sorted[i] <= 8'd0;
            end
            
            sort_pass <= 4'd0;
            sort_index <= 4'd0;
            dedup_index <= 4'd0;
            unique_count <= 4'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= READ;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                READ: begin
                    // Copy input array to internal buffer
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < len) begin
                            buffer[i] <= arr[i];
                        end else begin
                            buffer[i] <= 8'd0;
                        end
                    end
                    next_state <= SORT;
                end

                SORT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Bubble sort pass
                    if (sort_pass < len - 1) begin
                        if (sort_index < len - sort_pass - 1) begin
                            if (buffer[sort_index] > buffer[sort_index + 1]) begin
                                // Swap
                                reg [7:0] temp;
                                temp = buffer[sort_index];
                                buffer[sort_index] <= buffer[sort_index + 1];
                                buffer[sort_index + 1] <= temp;
                            end
                            sort_index <= sort_index + 4'd1;
                        end else begin
                            sort_index <= 4'd0;
                            sort_pass <= sort_pass + 4'd1;
                        end
                    end else begin
                        // Copy sorted array
                        integer i;
                        for (i = 0; i < 8; i = i + 1) begin
                            sorted[i] <= buffer[i];
                        end
                        sort_pass <= 4'd0;
                        sort_index <= 4'd0;
                        next_state <= DEDUP;
                    end
                end

                DEDUP: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Remove duplicates
                    if (dedup_index == 0) begin
                        // First element is always unique
                        result[0] <= sorted[0];
                        unique_count <= 4'd1;
                        dedup_index <= 4'd1;
                    end else if (dedup_index < len) begin
                        if (sorted[dedup_index] != sorted[dedup_index - 1]) begin
                            result[unique_count] <= sorted[dedup_index];
                            unique_count <= unique_count + 4'd1;
                        end
                        dedup_index <= dedup_index + 4'd1;
                    end else begin
                        // Done with deduplication
                        out_len <= unique_count;
                        
                        // Clear remaining result elements
                        integer i;
                        for (i = unique_count; i < 8; i = i + 1) begin
                            result[i] <= 8'd0;
                        end
                        
                        dedup_index <= 4'd0;
                        unique_count <= 4'd0;
                        next_state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule