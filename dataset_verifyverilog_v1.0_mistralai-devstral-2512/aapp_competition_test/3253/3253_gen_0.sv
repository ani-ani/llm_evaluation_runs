module election_solver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire state_valid,
    input wire [4:0] delegate_in,
    input wire [31:0] c_in,
    input wire [31:0] f_in,
    input wire [31:0] u_in,
    input wire [2:0] state_index,
    output reg [31:0] result,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH = 2'd3;
    
    reg [1:0] state;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;

    // State storage (4 states max)
    reg [4:0] delegates [0:3];
    reg [31:0] c [0:3];
    reg [31:0] f [0:3];
    reg [31:0] u [0:3];
    reg [2:0] state_count;

    // Binary search variables
    reg [31:0] low;
    reg [31:0] high;
    reg [31:0] mid;
    reg [31:0] min_voters;

    // DP table (delegates x states)
    reg [31:0] dp [0:4095];
    reg [11:0] delegate_sum;
    reg [2:0] state_idx;
    reg [31:0] max_c;

    // DP computation flags
    reg dp_computing;
    reg [11:0] dp_delegate;
    reg [2:0] dp_state;
    reg [31:0] dp_value;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            busy <= 1'b0;
            cycle_count <= 16'd0;
            state_count <= 3'd0;
            
            // Initialize state storage
            integer i;
            for (i = 0; i < 4; i = i + 1) begin
                delegates[i] <= 5'd0;
                c[i] <= 32'd0;
                f[i] <= 32'd0;
                u[i] <= 32'd0;
            end
            
            // Initialize DP variables
            dp_computing <= 1'b0;
            dp_delegate <= 12'd0;
            dp_state <= 3'd0;
            dp_value <= 32'd0;
            
            // Initialize binary search
            low <= 32'd0;
            high <= 32'd65535;
            mid <= 32'd0;
            min_voters <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                        busy <= 1'b1;
                        state_count <= 3'd0;
                    end
                end
                
                LOAD: begin
                    if (state_valid) begin
                        delegates[state_index] <= delegate_in;
                        c[state_index] <= c_in;
                        f[state_index] <= f_in;
                        u[state_index] <= u_in;
                        state_count <= state_count + 3'd1;
                        
                        if (state_count == 3'd3) begin
                            state <= COMPUTE;
                            cycle_count <= 16'd0;
                            
                            // Initialize binary search
                            low <= 32'd0;
                            high <= 32'd65535;
                            min_voters <= 32'd0;
                        end
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                        result <= 32'd-1;  // Impossible
                    end else begin
                        // Binary search for minimum voters
                        if (low <= high) begin
                            mid <= (low + high) >>> 1;
                            
                            // Check if mid voters can win election
                            // Initialize DP table
                            integer i, j;
                            for (i = 0; i < 4096; i = i + 1) begin
                                dp[i] <= 32'd0;
                            end
                            
                            // DP computation
                            dp_computing <= 1'b1;
                            dp_delegate <= 12'd0;
                            dp_state <= 3'd0;
                            
                            // Process each state
                            for (dp_state = 0; dp_state <= state_count; dp_state = dp_state + 1) begin
                                for (dp_delegate = 0; dp_delegate <= 4095; dp_delegate = dp_delegate + 1) begin
                                    if (dp_state == 0) begin
                                        // Base case: 0 delegates, 0 states
                                        if (dp_delegate == 0) begin
                                            dp[dp_delegate] <= 32'd0;
                                        end
                                    end else begin
                                        // Transition from previous state
                                        reg [31:0] prev_max;
                                        reg [31:0] current_max;
                                        reg [31:0] temp_c;
                                        
                                        prev_max <= dp[dp_delegate];
                                        
                                        // Try adding current state's delegates
                                        if (dp_delegate >= delegates[dp_state-1]) begin
                                            temp_c <= c[dp_state-1] + 
                                                     (mid <= u[dp_state-1] ? mid : u[dp_state-1]);
                                            current_max <= dp[dp_delegate - delegates[dp_state-1]] + temp_c;
                                            
                                            if (current_max > prev_max) begin
                                                dp[dp_delegate] <= current_max;
                                            end else begin
                                                dp[dp_delegate] <= prev_max;
                                            end
                                        end
                                    end
                                end
                            end
                            
                            dp_computing <= 1'b0;
                            
                            // Check if we can win
                            reg [31:0] total_f;
                            reg [31:0] total_c;
                            integer k;
                            
                            total_f <= 32'd0;
                            total_c <= 32'd0;
                            
                            for (k = 0; k < 4; k = k + 1) begin
                                total_f <= total_f + f[k];
                                total_c <= total_c + c[k];
                            end
                            
                            if (dp[4095] >= total_f) begin
                                // Can win with mid voters
                                min_voters <= mid;
                                high <= mid - 32'd1;
                            end else begin
                                low <= mid + 32'd1;
                            end
                        end else begin
                            // Binary search complete
                            state <= FINISH;
                            if (min_voters == 32'd0) begin
                                result <= 32'd0;
                            end else if (min_voters > 32'd65535) begin
                                result <= 32'd-1;  // Impossible
                            end else begin
                                result <= min_voters;
                            end
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // Busy signal logic
    always @(*) begin
        if (state == IDLE) begin
            busy = 1'b0;
        end else begin
            busy = 1'b1;
        end
    end

endmodule