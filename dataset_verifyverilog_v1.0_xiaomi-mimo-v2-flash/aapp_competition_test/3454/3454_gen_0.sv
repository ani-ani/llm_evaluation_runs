module PokenomPaint(
    input clk,
    input rst_n,
    input start,
    input [9:0] N,
    input [9:0] M,
    input [9:0] c_in,
    output reg [16:0] result,
    output reg [9:0] X,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD_C    = 3'd1;
    localparam [2:0] INIT_DP   = 3'd2;
    localparam [2:0] COMPUTE   = 3'd3;
    localparam [2:0] DONE      = 3'd4;

    // Modulo constant
    localparam [16:0] MOD = 17'd100003;

    // Internal registers
    reg [2:0] state;
    reg [9:0] counter;        // General purpose counter
    reg [9:0] col_idx;        // Current column index (0 to N)
    reg [9:0] height_idx;     // Current height index for DP calculation
    reg [9:0] H_limit;        // M - c[N] (target height)
    reg [9:0] H_max;          // M - c[i] for current column
    reg [16:0] dp_current;    // Current DP value
    reg [16:0] dp_prev;       // Previous DP value (from same height, previous col)
    reg [16:0] dp_sum;        // Accumulator for DP calculation
    reg [9:0] x_counter;      // Counter for 'X' (zeros)
    reg [17:0] temp_result;   // 18-bit temporary to hold sum before modulo

    // RAM for storing sequence c (depth N, max 1000)
    // Using LUTRAM style logic, implemented as register array for simplicity and reliability
    reg [9:0] c_ram [0:1023];
    reg [9:0] c_ram_rd_addr;
    reg [9:0] c_ram_wr_addr;
    reg c_ram_wr_en;
    reg [9:0] c_ram_rd_data;

    // DP state storage
    // We need to store the DP row for the previous column.
    // Size: Up to M (1000). We use registers for simplicity and speed.
    // Array size 1001 to handle heights 0 to 1000.
    reg [16:0] dp_row [0:1000];
    reg [16:0] dp_row_next [0:1000];

    // Variables for for-loops
    integer i;

    // RAM Read Logic
    always @(posedge clk) begin
        c_ram_rd_data <= c_ram[c_ram_rd_addr];
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 17'd0;
            X <= 10'd0;
            counter <= 10'd0;
            col_idx <= 10'd0;
            height_idx <= 10'd0;
            H_limit <= 10'd0;
            H_max <= 10'd0;
            dp_current <= 17'd0;
            dp_prev <= 17'd0;
            dp_sum <= 17'd0;
            x_counter <= 10'd0;
            temp_result <= 18'd0;
            c_ram_wr_addr <= 10'd0;
            c_ram_wr_en <= 1'b0;
            c_ram_rd_addr <= 10'd0;
            // Initialize DP arrays
            for (i = 0; i <= 1000; i = i + 1) begin
                dp_row[i] <= 17'd0;
                dp_row_next[i] <= 17'd0;
            end
        end else begin
            // Default assignments
            done <= 1'b0;
            c_ram_wr_en <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD_C;
                        counter <= 10'd0;
                        c_ram_wr_addr <= 10'd0;
                    end
                end

                LOAD_C: begin
                    // Load sequence c into RAM
                    if (counter < N) begin
                        c_ram[c_ram_wr_addr] <= c_in;
                        c_ram_wr_addr <= c_ram_wr_addr + 10'd1;
                        counter <= counter + 10'd1;
                        // Wait for c_in to stabilize or assume it's ready next cycle
                        // If input is streaming, we might need valid signal, but spec implies we just read.
                    end else begin
                        // Load complete, move to init
                        state <= INIT_DP;
                        counter <= 10'd0;
                        // Read c[N-1] to calculate H_limit
                        c_ram_rd_addr <= N - 10'd1;
                    end
                end

                INIT_DP: begin
                    // Calculate H_limit = M - c[N-1]
                    // Read latency of RAM is 1 cycle, so data available now
                    H_limit <= M - c_ram_rd_data;
                    
                    // Initialize DP row
                    // dp[0] = 1 for column 0 (technically column 1 in problem statement indexing)
                    // Reset DP arrays
                    for (i = 0; i <= 1000; i = i + 1) begin
                        dp_row[i] <= 17'd0;
                    end
                    dp_row[0] <= 17'd1;
                    
                    // Reset counters for Compute loop
                    col_idx <= 10'd1; // Start from column 1 (0 is base case)
                    x_counter <= 10'd0;
                    
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    // Iterate columns from 1 to N
                    if (col_idx <= N) begin
                        // Calculate H_max for this column
                        // Read c[col_idx - 1] (since col_idx starts at 1)
                        // We need to read RAM synchronously
                        c_ram_rd_addr <= col_idx - 10'd1;
                        
                        // Wait 1 cycle for RAM read
                        if (height_idx == 10'd0) begin
                            height_idx <= 10'd1; // Start height loop next cycle
                            // H_max calculation happens next cycle when c_ram_rd_data is valid
                            // For the first iteration of height loop (idx 0), we handle specifically
                        end

                        // Height loop logic
                        if (height_idx > 10'd0) begin
                            // We are inside the height loop for the current column
                            // Current height is height_idx
                            // H_max = M - c[col_idx-1]. c_ram_rd_data is valid from previous cycle if we updated address.
                            // Wait, we updated address in previous cycle of height_idx start.
                            // Let's re-structure: Update address, then use it in next state cycle or store it.
                            
                            // Let's use a temporary register for H_max calculation to avoid dependency issues
                            // Or calculate it when entering the column state.
                        end
                    end
                end
            endcase
        end
    end

endmodule