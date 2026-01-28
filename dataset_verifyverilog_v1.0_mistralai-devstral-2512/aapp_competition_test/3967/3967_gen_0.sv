module BambooCutScheduler(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    input wire [63:0] k,
    input wire [31:0] a [0:99],
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100000;

    // Binary search variables
    reg [31:0] low;
    reg [31:0] high;
    reg [31:0] mid;
    reg [31:0] max_a;
    reg [63:0] total_waste;
    reg [31:0] i;
    reg [31:0] temp_waste;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            low <= 32'd1;
            high <= 32'd0;
            mid <= 32'd0;
            max_a <= 32'd0;
            total_waste <= 64'd0;
            i <= 32'd0;
            temp_waste <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Initialize binary search bounds
                        max_a <= 32'd0;
                        for (i = 0; i < n; i = i + 1) begin
                            if (a[i] > max_a) begin
                                max_a <= a[i];
                            end
                        end
                        high <= max_a + k[31:0] + 32'd1;  // Use lower 32 bits of k
                        low <= 32'd1;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Binary search
                    if (low < high) begin
                        mid <= (low + high) / 2;
                        
                        // Compute total waste for mid
                        total_waste <= 64'd0;
                        for (i = 0; i < n; i = i + 1) begin
                            // Compute (a[i]-1) mod mid
                            if (mid == 32'd1) begin
                                temp_waste <= 32'd0;  // mod 1 is 0
                            end else begin
                                temp_waste <= (a[i] - 32'd1) % mid;
                            end
                            
                            // waste = (mid-1) - temp_waste
                            if (mid == 32'd1) begin
                                temp_waste <= 32'd0;  // waste = 0 when mid=1
                            end else begin
                                temp_waste <= (mid - 32'd1) - temp_waste;
                            end
                            
                            total_waste <= total_waste + temp_waste;
                        end
                        
                        // Check if waste <= k
                        if (total_waste <= k) begin
                            low <= mid + 32'd1;  // Try larger d
                        end else begin
                            high <= mid;  // Try smaller d
                        end
                    end else begin
                        // Search complete
                        result <= low - 32'd1;  // Return last valid d
                        state <= FINISH;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        result <= low - 32'd1;
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule