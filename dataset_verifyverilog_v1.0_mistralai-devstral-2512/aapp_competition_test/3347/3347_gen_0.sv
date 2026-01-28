module GoldStoreScheduler(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [7:0] t_i,
    input wire [7:0] h_i,
    input wire [3:0] addr,
    output reg [4:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Internal storage for t and h values
    reg [7:0] t_mem [0:15];
    reg [7:0] h_mem [0:15];
    reg [3:0] load_count;

    // DP array: min_time[c] = minimum time to visit c stores
    reg [15:0] min_time [0:16];
    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            load_count <= 4'd0;
            
            // Initialize min_time array
            for (i = 0; i < 16; i = i + 1) begin
                min_time[i] <= 16'd65535;  // Initialize to large value (infinity)
            end
            min_time[0] <= 16'd0;  // Base case: 0 stores visited at time 0
            
            // Initialize memory
            for (i = 0; i < 16; i = i + 1) begin
                t_mem[i] <= 8'd0;
                h_mem[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= LOAD;
                        load_count <= 4'd0;
                    end
                end
                
                LOAD: begin
                    // Load input data into memory
                    if (load_count < n) begin
                        t_mem[load_count] <= t_i;
                        h_mem[load_count] <= h_i;
                        load_count <= load_count + 4'd1;
                    end else begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Process stores in order (no sorting for simplicity)
                    // Update DP array for each store
                    for (i = 0; i < n; i = i + 1) begin
                        for (j = n; j >= 1; j = j - 1) begin
                            if (min_time[j-1] + t_mem[i] <= h_mem[i] && 
                                min_time[j-1] + t_mem[i] < min_time[j]) begin
                                min_time[j] <= min_time[j-1] + t_mem[i];
                            end
                        end
                    end
                    
                    // Find maximum count with valid time
                    result <= 5'd0;
                    for (i = 15; i >= 0; i = i - 1) begin
                        if (min_time[i] < 16'd65535) begin
                            result <= i;
                        end
                    end
                    
                    state <= FINISH;
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