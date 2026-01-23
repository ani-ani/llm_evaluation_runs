module coin_game (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [6:0] n,          // Number of chests (1-100)
    input wire [9:0] a [0:99],   // Coin counts (100 elements)
    output reg signed [19:0] result, // Result or -1 for invalid
    output reg done              // Computation finished
);

// State definitions
localparam [2:0] IDLE = 3'b000;
localparam [2:0] COPY = 3'b001;
localparam [2:0] COMP = 3'b010;
localparam [2:0] FINISH = 3'b011;
localparam [2:0] ERROR = 3'b100;

reg [2:0] state;
reg signed [15:0] mem [0:99];   // Internal storage for coins
reg [6:0] x;                    // Current index
reg signed [19:0] total_moves;  // Accumulated moves
reg signed [19:0] result_reg;   // Result register
reg done_reg;                   // Done signal register

integer i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done_reg <= 1'b0;
        result_reg <= 20'sd0;
        x <= 7'd0;
        total_moves <= 20'sd0;
        // Initialize memory
        for (i = 0; i < 100; i = i + 1) begin
            mem[i] <= 16'sd0;
        end
    end else begin
        done_reg <= 1'b0; // Default done to 0
        case (state)
            IDLE: begin
                if (start) begin
                    if (n == 7'd1 || n[0] == 1'b0) begin // n==1 or even
                        state <= ERROR;
                    end else begin
                        state <= COPY;
                        x <= n >> 1; // Start from floor(n/2)
                        total_moves <= 20'sd0;
                    end
                end
            end
            
            COPY: begin
                // Copy input array to internal memory
                for (i = 0; i < 100; i = i + 1) begin
                    if (i < n)
                        mem[i] <= {6'd0, a[i]}; // Sign-extend to 16 bits
                    else
                        mem[i] <= 16'sd0;
                end
                state <= COMP;
            end
            
            COMP: begin
                if (x >= 7'd1) begin
                    // Calculate children indices (1-indexed to 0-indexed)
                    // Chest x at index x-1, children at 2x-1 and 2x
                    if (2*x <= n && 2*x+1 <= n) begin
                        // Both children exist
                        if (mem[2*x-1] > mem[2*x]) 
                            total_moves <= total_moves + mem[2*x-1];
                        else 
                            total_moves <= total_moves + mem[2*x];
                        
                        mem[x-1] <= mem[x-1] - 
                                    ((mem[2*x-1] > mem[2*x]) ? mem[2*x-1] : mem[2*x]);
                    end
                    x <= x - 7'd1;
                end else begin
                    state <= FINISH;
                end
            end
            
            FINISH: begin
                if (mem[0] > 16'sd0)
                    result_reg <= total_moves + mem[0];
                else
                    result_reg <= total_moves;
                done_reg <= 1'b1;
                state <= IDLE;
            end
            
            ERROR: begin
                result_reg <= -20'sd1; // -1 in 20-bit signed
                done_reg <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

// Assign outputs
always @(*) begin
    result = result_reg;
    done = done_reg;
end

endmodule