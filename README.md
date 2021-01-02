# 5g_Simulation_MATLAB

# Project Objective:

To have an algorithm which performs better than the already existing scheduling
algorithms and to compare them with each other.
The proposed scheduling algorithm is:

# Modified Proportional Fair – Best CQI algorithm (MPF-BCQI)

The algorithm tries to satisfy both the average throughput and the fairness enhanced with new
averaging methods.
The first is the modification of PF based on changing the method used to compute the
average throughput for the user. These methods are: Median, Range and Geometric Mean
methods.
The second is calculating the metric for each UE as a combination of PF and best CQI metric
in order to achieve better channel allocation for the user while satisfying the fairness between
users.

These are the ideas based on Mai Ali Ibrahim, Nada et al, “A Proposed Modified
Proportional Fairness Scheduling (MPF-BCQI) Algorithm with Best CQI Consideration for
LTE-A Networks”, 2018 13th International Conference on Computer Engineering and
Systems (ICCES)

![Selection_186](https://user-images.githubusercontent.com/57367559/103449082-21fa4f80-4c71-11eb-9e63-0805e06390f4.png)
![Selection_187](https://user-images.githubusercontent.com/57367559/103449084-24f54000-4c71-11eb-9d86-4cd100fbee0c.png)

# Final Observations :
1. MPF-BCQI vs Traditional PF :
Has the ability to provide fairness even though it starves some users in the
channel. But with CQI part of the scheduling algorithm, it guarantees higher
throughput than traditional PF.

2. MPF-BCQI vs Traditional BestCQI :
Selects the user with the highest CQI value that means better channel
condition in order to get the RB allocation for each time, although some of the
fairness is not preserved and can be improved by geometric mean method.

# Conclusion:
The Growth of mobile communication technologies offers many opportunities and
challenges in satisfying the QoS requirements for the new real-time applications such as
streaming multimedia and online gaming. The main feature of it is QoS supporting many
application types. To achieve strong support for QoS, 5G needs a high performance packet
scheduling algorithm. In this approach, a new scheduling algorithm is proposed based on
changing the average throughput computational equation in PF algorithm and on the
combination of PF and Best CQI metrics. Using the simulation evaluation of the proposed
algorithms, the proposed modified PF algorithm, compared to others showed promising
results. Moreover, the proposed MPF-BCQI scheduling algorithm compared to the original
PF and the Best CQI Schedulers shows a good compromise between fairness and throughput
and in future can also be improvised using other averaging methods.

# Reference:
Mai Ali Ibrahim, Nada et al, “A Proposed Modified Proportional Fairness Scheduling (MPF-BCQI)
Algorithm with Best CQI Consideration for LTE-A Networks”, 2018 13th International Conference
on Computer Engineering and Systems (ICCES).
