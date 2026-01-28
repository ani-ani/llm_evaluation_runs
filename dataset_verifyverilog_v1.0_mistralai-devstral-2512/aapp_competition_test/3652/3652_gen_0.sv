module DeleteColumnsToSort(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] N,
    input wire [3:0] row0 [0:15],
    input wire [3:0] row1 [0:15],
    input wire [3:0] row2 [0:15],
    output reg [4:0] min_deletions,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] LOAD    = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] OUTPUT  = 2'd3;
    
    reg [1:0] state;
    reg [15:0] mask;
    reg [4:0] max_popcount;
    reg [4:0] current_popcount;
    reg [4:0] i, j;
    reg [3:0] count0 [1:16];
    reg [3:0] count1 [1:16];
    reg [3:0] count2 [1:16];
    reg [4:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd65535;

    // Initialize counts
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            mask <= 16'd0;
            max_popcount <= 5'd0;
            current_popcount <= 5'd0;
            i <= 5'd0;
            j <= 5'd0;
            for (k = 1; k <= 16; k = k + 1) begin
                count0[k] <= 4'd0;
                count1[k] <= 4'd0;
                count2[k] <= 4'd0;
            end
            cycle_count <= 16'd0;
            min_deletions <= 5'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    // Initialize counts for new computation
                    for (k = 1; k <= 16; k = k + 1) begin
                        count0[k] <= 4'd0;
                        count1[k] <= 4'd0;
                        count2[k] <= 4'd0;
                    end
                    mask <= 16'd0;
                    max_popcount <= 5'd0;
                    state <= COMPUTE;
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    // Reset counts for current mask
                    for (k = 1; k <= 16; k = k + 1) begin
                        count0[k] <= 4'd0;
                        count1[k] <= 4'd0;
                        count2[k] <= 4'd0;
                    end
                    
                    // Count values in selected columns for each row
                    for (i = 0; i < N; i = i + 1) begin
                        if (mask[i]) begin
                            count0[row0[i]] <= count0[row0[i]] + 4'd1;
                            count1[row1[i]] <= count1[row1[i]] + 4'd1;
                            count2[row2[i]] <= count2[row2[i]] + 4'd1;
                        end
                    end
                    
                    // Check if counts match
                    reg match;
                    match = 1'b1;
                    for (j = 1; j <= N; j = j + 1) begin
                        if (count0[j] != count1[j] || count0[j] != count2[j]) begin
                            match = 1'b0;
                        end
                    end
                    
                    // Update max_popcount if match
                    current_popcount = popcount(mask);
                    if (match && current_popcount > max_popcount) begin
                        max_popcount <= current_popcount;
                    end
                    
                    // Move to next mask
                    mask <= mask + 16'd1;
                    
                    // Check if done with all masks
                    if (mask == (16'd1 << N) || cycle_count >= MAX_CYCLES) begin
                        state <= OUTPUT;
                    end
                end
                
                OUTPUT: begin
                    min_deletions <= N - max_popcount;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // Popcount function for 16-bit mask
    function [4:0] popcount;
        input [15:0] mask;
        integer k;
        reg [4:0] count;
        begin
            count = 5'd0;
            for (k = 0; k < 16; k = k + 1) begin
                if (mask[k]) begin
                    count = count + 5'd1;
                end
            end
            popcount = count;
        end
    endfunction

endmodule