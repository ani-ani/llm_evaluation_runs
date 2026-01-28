module sorted_union(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr1 [0:7],
    input wire [7:0] arr2 [0:7],
    input wire [3:0] len1,
    input wire [3:0] len2,
    output reg [7:0] result [0:15],
    output reg [15:0] valid,
    output reg [4:0] len_out,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COMBINE = 3'd1;
    localparam [2:0] SORT    = 3'd2;
    localparam [2:0] DEDUP   = 3'd3;
    localparam [2:0] COMPLETE = 3'd4;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd50;

    // Working array (16 elements, 8-bit each)
    reg [7:0] work_array [0:15];
    reg [15:0] work_valid;
    reg [4:0] work_len;

    // Sorting variables
    integer i, j;
    reg [7:0] temp;

    // Deduplication variables
    reg [15:0] dedup_valid;
    reg [4:0] dedup_len;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            done <= 1'b0;
            len_out <= 5'd0;
            
            // Initialize all outputs
            for (i = 0; i < 16; i = i + 1) begin
                result[i] <= 8'd0;
                valid[i] <= 1'b0;
            end
            
            // Initialize working array
            for (i = 0; i < 16; i = i + 1) begin
                work_array[i] <= 8'd0;
            end
            work_valid <= 16'd0;
            work_len <= 5'd0;
            
            // Initialize deduplication registers
            dedup_valid <= 16'd0;
            dedup_len <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMBINE;
                    end
                end

                COMBINE: begin
                    // Combine arr1 and arr2 into work_array
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < len1) begin
                            work_array[i] <= arr1[i];
                            work_valid[i] <= 1'b1;
                        end else begin
                            work_array[i] <= 8'd0;
                            work_valid[i] <= 1'b0;
                        end
                    end
                    
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < len2) begin
                            work_array[i + 8] <= arr2[i];
                            work_valid[i + 8] <= 1'b1;
                        end else begin
                            work_array[i + 8] <= 8'd0;
                            work_valid[i + 8] <= 1'b0;
                        end
                    end
                    
                    // Calculate combined length
                    work_len <= len1 + len2;
                    state <= SORT;
                    cycle_count <= cycle_count + 8'd1;
                end

                SORT: begin
                    // Simple bubble sort implementation
                    for (i = 0; i < 15; i = i + 1) begin
                        for (j = 0; j < 15 - i; j = j + 1) begin
                            if (work_valid[j] && work_valid[j + 1] && work_array[j] > work_array[j + 1]) begin
                                // Swap elements
                                temp <= work_array[j];
                                work_array[j] <= work_array[j + 1];
                                work_array[j + 1] <= temp;
                            end
                        end
                    end
                    
                    state <= DEDUP;
                    cycle_count <= cycle_count + 8'd1;
                end

                DEDUP: begin
                    // Remove duplicates by shifting
                    dedup_valid[0] <= work_valid[0];
                    dedup_len <= work_valid[0] ? 1 : 0;
                    
                    for (i = 1; i < 16; i = i + 1) begin
                        if (work_valid[i] && (work_array[i] != work_array[i - 1] || !work_valid[i - 1])) begin
                            dedup_valid[i] <= 1'b1;
                            dedup_len <= dedup_len + 1;
                        end else begin
                            dedup_valid[i] <= 1'b0;
                        end
                    end
                    
                    state <= COMPLETE;
                    cycle_count <= cycle_count + 8'd1;
                end

                COMPLETE: begin
                    // Latch results
                    for (i = 0; i < 16; i = i + 1) begin
                        result[i] <= work_array[i];
                        valid[i] <= dedup_valid[i];
                    end
                    len_out <= dedup_len;
                    done <= 1'b1;
                    
                    // Return to idle
                    if (cycle_count >= MAX_CYCLES || done) begin
                        state <= IDLE;
                    end else begin
                        state <= COMPLETE;
                    end
                    cycle_count <= cycle_count + 8'd1;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule