module barica #(
    parameter MAX_N = 8
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    input wire [7:0] N,          // Number of plants (2 <= N <= MAX_N)
    input wire [7:0] K,          // Energy cost per jump
    
    // Plant data arrays
    input wire [7:0] X [0:MAX_N-1],
    input wire [7:0] Y [0:MAX_N-1],
    input wire [7:0] F [0:MAX_N-1],
    
    // Outputs
    output reg done,
    output reg [15:0] final_energy,
    output reg [7:0] path_length,    // Number of plants in the path
    output reg [7:0] path_indices [0:MAX_N-1]  // Plant indices (1-based)
);

// State definitions
localparam [3:0] S_IDLE        = 4'd0;
localparam [3:0] S_INIT        = 4'd1;
localparam [3:0] S_START_PASS  = 4'd2;
localparam [3:0] S_SETUP_I     = 4'd3;
localparam [3:0] S_CHECK_I     = 4'd4;
localparam [3:0] S_SETUP_J     = 4'd5;
localparam [3:0] S_CHECK_J     = 4'd6;
localparam [3:0] S_UPDATE      = 4'd7;
localparam [3:0] S_INC_J       = 4'd8;
localparam [3:0] S_INC_I       = 4'd9;
localparam [3:0] S_PATH_INIT   = 4'd10;
localparam [3:0] S_PATH_LOOP   = 4'd11;
localparam [3:0] S_PATH_REVERSE= 4'd12;
localparam [3:0] S_PATH_DONE   = 4'd13;

reg [3:0] state;
reg [3:0] pass_counter;
reg [3:0] i_counter;
reg [3:0] j_counter;
reg [3:0] path_idx;
reg [3:0] current_idx;
reg [3:0] rev_counter;

// DP storage
reg [15:0] dp [0:MAX_N-1];
reg [7:0] pred [0:MAX_N-1];
reg valid [0:MAX_N-1];

// Temporary registers
reg [15:0] new_energy;

// Path storage (reverse order)
reg [7:0] path_rev [0:MAX_N-1];

integer i;

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        done <= 1'b0;
        state <= S_IDLE;
        
        // Initialize all registers
        pass_counter <= 4'd0;
        i_counter <= 4'd0;
        j_counter <= 4'd0;
        path_idx <= 4'd0;
        current_idx <= 4'd0;
        rev_counter <= 4'd0;
        new_energy <= 16'd0;
        
        for (i = 0; i < MAX_N; i = i + 1) begin
            dp[i] <= 16'd0;
            pred[i] <= 8'd0;
            valid[i] <= 1'b0;
            path_rev[i] <= 8'd0;
            path_indices[i] <= 8'd0;
        end
        
        final_energy <= 16'd0;
        path_length <= 8'd0;
    end else begin
        case (state)
            S_IDLE: begin
                if (start) begin
                    state <= S_INIT;
                    done <= 1'b0;
                end
            end
            
            S_INIT: begin
                // Initialize dp, pred, valid
                for (i = 0; i < MAX_N; i = i + 1) begin
                    if (i == 0) begin
                        dp[i] <= F[0];
                        valid[i] <= 1'b1;
                    end else begin
                        dp[i] <= 16'd0;
                        valid[i] <= 1'b0;
                    end
                    pred[i] <= 8'd0;
                end
                pass_counter <= 4'd0;
                state <= S_START_PASS;
            end
            
            S_START_PASS: begin
                if (pass_counter >= N) begin
                    state <= S_PATH_INIT;
                end else begin
                    i_counter <= 4'd0;
                    state <= S_SETUP_I;
                end
            end
            
            S_SETUP_I: begin
                if (i_counter >= N) begin
                    pass_counter <= pass_counter + 1;
                    state <= S_START_PASS;
                end else begin
                    if (valid[i_counter] && (dp[i_counter] >= K)) begin
                        j_counter <= 4'd0;
                        state <= S_SETUP_J;
                    end else begin
                        i_counter <= i_counter + 1;
                        state <= S_SETUP_I;
                    end
                end
            end
            
            S_SETUP_J: begin
                if (j_counter >= N) begin
                    i_counter <= i_counter + 1;
                    state <= S_SETUP_I;
                end else begin
                    if (j_counter == i_counter) begin
                        state <= S_INC_J;
                    end else begin
                        state <= S_CHECK_J;
                    end
                end
            end
            
            S_CHECK_J: begin
                if ((X[i_counter] == X[j_counter] && Y[i_counter] < Y[j_counter]) ||
                    (Y[i_counter] == Y[j_counter] && X[i_counter] < X[j_counter])) begin
                    new_energy <= dp[i_counter] - K + F[j_counter];
                    state <= S_UPDATE;
                end else begin
                    state <= S_INC_J;
                end
            end
            
            S_UPDATE: begin
                if (!valid[j_counter] || (new_energy > dp[j_counter])) begin
                    dp[j_counter] <= new_energy;
                    pred[j_counter] <= i_counter;
                    valid[j_counter] <= 1'b1;
                end
                state <= S_INC_J;
            end
            
            S_INC_J: begin
                j_counter <= j_counter + 1;
                state <= S_SETUP_J;
            end
            
            S_PATH_INIT: begin
                path_idx <= 4'd0;
                current_idx <= N - 1;
                rev_counter <= 4'd0;
                state <= S_PATH_LOOP;
            end
            
            S_PATH_LOOP: begin
                if (current_idx == 0) begin
                    path_rev[path_idx] <= 8'd0;
                    path_length <= path_idx + 1;
                    state <= S_PATH_REVERSE;
                end else begin
                    path_rev[path_idx] <= current_idx;
                    current_idx <= pred[current_idx];
                    path_idx <= path_idx + 1;
                    state <= S_PATH_LOOP;
                end
            end
            
            S_PATH_REVERSE: begin
                if (rev_counter < path_length) begin
                    path_indices[rev_counter] <= path_rev[path_length - 1 - rev_counter] + 8'd1;
                    rev_counter <= rev_counter + 1;
                    state <= S_PATH_REVERSE;
                end else begin
                    state <= S_PATH_DONE;
                end
            end
            
            S_PATH_DONE: begin
                final_energy <= dp[N-1];
                done <= 1'b1;
                state <= S_IDLE;
            end
            
            default: state <= S_IDLE;
        endcase
    end
end

endmodule