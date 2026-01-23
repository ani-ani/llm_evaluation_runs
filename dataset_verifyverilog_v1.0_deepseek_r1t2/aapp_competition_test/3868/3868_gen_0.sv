module min_cost_gather #(
    parameter N = 2,
    parameter MAX_FLIGHTS = 8,
    parameter MAX_DAY = 16
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [28*MAX_FLIGHTS-1:0] flights,
    output reg [19:0] min_cost,
    output reg done
);

// State definitions
localparam [2:0] IDLE = 3'b000;
localparam [2:0] INIT_ARRIVALS = 3'b001;
localparam [2:0] PROCESS_ARRIVALS = 3'b010;
localparam [2:0] INIT_DEPARTURES = 3'b011;
localparam [2:0] PROCESS_DEPARTURES = 3'b100;
localparam [2:0] COMPUTE_MIN = 3'b101;
localparam [2:0] FINISHED = 3'b110;

// Internal registers
reg [2:0] state;
reg [4:0] day_counter;
reg [3:0] flight_counter;
reg [19:0] arrival_cost_per_city [1:N];
reg [19:0] departure_cost_per_city [1:N];
reg [19:0] arrival_cost [1:MAX_DAY];
reg [19:0] departure_cost [1:MAX_DAY];
reg [19:0] total_arrival_cost;
reg [19:0] total_departure_cost;
reg [3:0] arrival_count;
reg [3:0] departure_count;
reg [19:0] best_cost;
reg [4:0] compute_day;
integer i, j;

// Flight unpacking
genvar idx;
generate
    for (idx = 0; idx < MAX_FLIGHTS; idx = idx + 1) begin : flight_unpack
        wire valid;
        wire [4:0] day;
        wire [2:0] from;
        wire [2:0] to;
        wire [15:0] cost;
        
        assign valid = flights[idx*28 + 27];
        assign day   = flights[idx*28 + 26:idx*28 + 22];
        assign from  = flights[idx*28 + 21:idx*28 + 19];
        assign to    = flights[idx*28 + 18:idx*28 + 16];
        assign cost  = flights[idx*28 + 15:idx*28];
    end
endgenerate

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all registers
        state <= IDLE;
        done <= 1'b0;
        min_cost <= 20'hFFFFF;
        day_counter <= 5'd0;
        flight_counter <= 4'd0;
        total_arrival_cost <= 20'd0;
        total_departure_cost <= 20'd0;
        arrival_count <= 4'd0;
        departure_count <= 4'd0;
        best_cost <= 20'hFFFFF;
        compute_day <= 5'd0;
        
        // Initialize array registers
        for (i = 1; i <= N; i = i + 1) begin
            arrival_cost_per_city[i] <= 20'hFFFFF;
            departure_cost_per_city[i] <= 20'hFFFFF;
        end
        
        for (i = 1; i <= MAX_DAY; i = i + 1) begin
            arrival_cost[i] <= 20'hFFFFF;
            departure_cost[i] <= 20'hFFFFF;
        end
    end
    else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= INIT_ARRIVALS;
                end
            end
            
            INIT_ARRIVALS: begin
                total_arrival_cost <= 20'd0;
                arrival_count <= 4'd0;
                for (j = 1; j <= N; j = j + 1) begin
                    arrival_cost_per_city[j] <= 20'hFFFFF;
                end
                day_counter <= 5'd1;
                flight_counter <= 4'd0;
                state <= PROCESS_ARRIVALS;
            end
            
            PROCESS_ARRIVALS: begin
                if (flight_counter < MAX_FLIGHTS) begin
                    if (flight_unpack[flight_counter].valid && 
                        flight_unpack[flight_counter].to == 3'd0 &&
                        flight_unpack[flight_counter].day == day_counter) begin
                        
                        reg [2:0] city = flight_unpack[flight_counter].from;
                        if (city >= 3'd1 && city <= N) begin
                            if (arrival_cost_per_city[city] > {4'd0, flight_unpack[flight_counter].cost}) begin
                                if (arrival_cost_per_city[city] == 20'hFFFFF) begin
                                    arrival_count <= arrival_count + 4'd1;
                                end
                                else begin
                                    total_arrival_cost <= total_arrival_cost - arrival_cost_per_city[city];
                                end
                                arrival_cost_per_city[city] <= {4'd0, flight_unpack[flight_counter].cost};
                                total_arrival_cost <= total_arrival_cost + {4'd0, flight_unpack[flight_counter].cost};
                            end
                        end
                    end
                    flight_counter <= flight_counter + 4'd1;
                end
                else begin
                    arrival_cost[day_counter] <= (arrival_count == N) ? total_arrival_cost : 20'hFFFFF;
                    
                    if (day_counter < MAX_DAY) begin
                        day_counter <= day_counter + 5'd1;
                        flight_counter <= 4'd0;
                    end
                    else begin
                        state <= INIT_DEPARTURES;
                    end
                end
            end
            
            INIT_DEPARTURES: begin
                total_departure_cost <= 20'd0;
                departure_count <= 4'd0;
                for (j = 1; j <= N; j = j + 1) begin
                    departure_cost_per_city[j] <= 20'hFFFFF;
                end
                day_counter <= MAX_DAY;
                flight_counter <= 4'd0;
                state <= PROCESS_DEPARTURES;
            end
            
            PROCESS_DEPARTURES: begin
                if (flight_counter < MAX_FLIGHTS) begin
                    if (flight_unpack[flight_counter].valid &&
                        flight_unpack[flight_counter].from == 3'd0 &&
                        flight_unpack[flight_counter].day == day_counter) begin
                        
                        reg [2:0] city = flight_unpack[flight_counter].to;
                        if (city >= 3'd1 && city <= N) begin
                            if (departure_cost_per_city[city] > {4'd0, flight_unpack[flight_counter].cost}) begin
                                if (departure_cost_per_city[city] == 20'hFFFFF) begin
                                    departure_count <= departure_count + 4'd1;
                                end
                                else begin
                                    total_departure_cost <= total_departure_cost - departure_cost_per_city[city];
                                end
                                departure_cost_per_city[city] <= {4'd0, flight_unpack[flight_counter].cost};
                                total_departure_cost <= total_departure_cost + {4'd0, flight_unpack[flight_counter].cost};
                            end
                        end
                    end
                    flight_counter <= flight_counter + 4'd1;
                end
                else begin
                    departure_cost[day_counter] <= (departure_count == N) ? total_departure_cost : 20'hFFFFF;
                    
                    if (day_counter > 5'd1) begin
                        day_counter <= day_counter - 5'd1;
                        flight_counter <= 4'd0;
                    end
                    else begin
                        state <= COMPUTE_MIN;
                        compute_day <= 5'd1;
                        best_cost <= 20'hFFFFF;
                    end
                end
            end
            
            COMPUTE_MIN: begin
                if (compute_day <= MAX_DAY) begin
                    if (arrival_cost[compute_day] != 20'hFFFFF && 
                        departure_cost[compute_day] != 20'hFFFFF) begin
                        
                        if ((arrival_cost[compute_day] + departure_cost[compute_day]) < best_cost) begin
                            best_cost <= arrival_cost[compute_day] + departure_cost[compute_day];
                        end
                    end
                    compute_day <= compute_day + 5'd1;
                end
                else begin
                    min_cost <= best_cost;
                    state <= FINISHED;
                end
            end
            
            FINISHED: begin
                done <= 1'b1;
                if (!start) begin
                    state <= IDLE;
                end
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule